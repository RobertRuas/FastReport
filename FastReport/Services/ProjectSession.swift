import AppKit
import Foundation
import Observation

enum WorkspaceMode: Equatable {
    case gallery
    case triage
}

@MainActor
@Observable
final class ProjectSession {
    private(set) var project: OpenedProject
    private(set) var photos: [DiskPhoto] = []
    private(set) var stats: ImportStats?
    private(set) var importProgress: (done: Int, total: Int)?
    private(set) var failure: AppFailure?
    private(set) var undoStack: [UndoRecord] = []
    private(set) var buffer = ClassificationBuffer()
    private(set) var mode: WorkspaceMode = .gallery
    private(set) var triagePhotos: [DiskPhoto] = []
    private(set) var triageIndex = 0
    private(set) var isImporting = false
    private(set) var imageRevision = 0

    var settings: ImageExportSettings
    private let organizer = FileOrganizer()
    private let watcher = FolderWatcher()
    private var ignoringWatcher = false
    private var reloadTask: Task<Void, Never>?

    init(project: OpenedProject, settings: ImageExportSettings = .default) {
        self.project = project
        self.settings = settings
        reload()
        startWatcher()
    }

    var inbox: [DiskPhoto] { photos.filter { $0.slotId == project.map.inbox?.id } }
    var classifiedCount: Int {
        photos.filter { photo in
            guard let slot = project.map.slot(id: photo.slotId) else { return false }
            return !slot.isInbox && !slot.isTrash
        }.count
    }
    var countableTotal: Int {
        photos.filter { project.map.slot(id: $0.slotId)?.isTrash != true }.count
    }
    var pendingCount: Int { inbox.count }
    var showsFolderReview: Bool { classifiedCount > 0 }
    var currentTriagePhoto: DiskPhoto? {
        guard triagePhotos.indices.contains(triageIndex) else { return nil }
        return triagePhotos[triageIndex]
    }
    var currentSlotLabel: String {
        guard let photo = currentTriagePhoto, let slot = project.map.slot(id: photo.slotId) else { return "" }
        if slot.isInbox { return "Inbox" }
        return slot.folder
    }

    func photos(in slot: Slot) -> [DiskPhoto] {
        photos.filter { $0.slotId == slot.id }
    }

    func displaySlots() -> [Slot] {
        let map = project.map
        let numbered = map.slots
            .filter { $0.id.hasPrefix("t") && !$0.isTrash && !$0.isInbox }
            .sorted { lhs, rhs in
                (Int(lhs.folder.dropFirst()) ?? 0) < (Int(rhs.folder.dropFirst()) ?? 0)
            }
        let general = map.slots.filter { $0.folder == "General" }
        let other = map.classificationSlots.filter { $0.folder != "General" && !numbered.contains($0) }
        let inboxSlot = [map.inbox].compactMap { $0 }
        let trash = [map.trash].compactMap { $0 }
        return (general + numbered + other + inboxSlot + trash).filter { !photos(in: $0).isEmpty }
    }

    func reload() {
        do {
            photos = try ProjectScanner.photos(in: project)
            if mode == .triage {
                refreshTriageListKeepingCurrent()
            }
            failure = nil
        } catch {
            failure = AppFailure(error)
        }
    }

    func importURLs(_ urls: [URL], locale: Locale) async {
        guard !urls.isEmpty else { return }
        isImporting = true
        importProgress = (0, urls.count)
        failure = nil
        ignoringWatcher = true
        defer {
            ignoringWatcher = false
            isImporting = false
            importProgress = nil
        }
        let importer = PhotoImporter(settings: settings)
        let images = importer.collectImages(from: urls)
        importProgress = (0, max(images.count, 1))
        var combined = ImportStats()
        for (index, url) in images.enumerated() {
            let piece = importer.importFiles([url], into: project)
            combined.attempted += piece.attempted
            combined.imported += piece.imported
            combined.converted += piece.converted
            combined.alreadyJPEG += piece.alreadyJPEG
            combined.skipped += piece.skipped
            combined.failed.append(contentsOf: piece.failed)
            importProgress = (index + 1, images.count)
        }
        if images.isEmpty {
            combined = importer.importFiles(urls, into: project)
        }
        stats = combined
        reload()
        if combined.hasFailures {
            failure = AppFailure(
                code: "import.partial",
                message: String(localized: "error.import.partial", locale: locale),
                debugDescription: combined.failed.joined(separator: ", ")
            )
        }
    }

    func startTriage(slot: Slot? = nil, startingAt photo: DiskPhoto? = nil) {
        if let slot {
            triagePhotos = photos(in: slot)
        } else {
            triagePhotos = inbox
        }
        if let photo, let index = triagePhotos.firstIndex(of: photo) {
            triageIndex = index
        } else {
            triageIndex = 0
        }
        buffer.clear()
        mode = .triage
    }

    func exitTriage() {
        mode = .gallery
        buffer.clear()
        triagePhotos = []
        triageIndex = 0
    }

    func handleKey(_ character: Character) {
        buffer.append(character)
    }

    func clearBuffer() {
        buffer.clear()
    }

    func commitBuffer(locale: Locale) {
        guard let slot = buffer.slot(in: project.map) else {
            if !buffer.text.isEmpty {
                failure = AppFailure(
                    code: "triage.hotkey",
                    message: String(localized: "error.triage.hotkey", locale: locale)
                )
            }
            buffer.clear()
            return
        }
        moveCurrent(to: slot, locale: locale)
        buffer.clear()
    }

    func trashCurrent(locale: Locale) {
        guard let trash = project.map.trash else {
            failure = AppFailure(OrganizerError.missingTrash, locale: locale)
            return
        }
        moveCurrent(to: trash, locale: locale)
    }

    func skipCurrent() {
        guard !triagePhotos.isEmpty else { return }
        triageIndex = (triageIndex + 1) % triagePhotos.count
        buffer.clear()
    }

    func goPrevious() {
        guard !triagePhotos.isEmpty else { return }
        triageIndex = (triageIndex - 1 + triagePhotos.count) % triagePhotos.count
        buffer.clear()
    }

    func goNext() {
        skipCurrent()
    }

    func rotateCurrent(locale: Locale) {
        guard let photo = currentTriagePhoto else { return }
        ignoringWatcher = true
        defer { ignoringWatcher = false }
        do {
            try ImagePipeline.rotateClockwise(at: photo.url, settings: settings)
            ThumbnailStore.shared.removeAll()
            imageRevision += 1
            failure = nil
        } catch {
            failure = AppFailure(error, locale: locale)
        }
    }

    func undoLast(locale: Locale) {
        guard let record = undoStack.popLast() else {
            failure = AppFailure(OrganizerError.nothingToUndo, locale: locale)
            return
        }
        ignoringWatcher = true
        defer { ignoringWatcher = false }
        do {
            try organizer.undo(record)
            reload()
            if mode == .triage {
                startTriage(slot: currentTriageScopeSlot(), startingAt: photos.first { $0.url.path == record.from.path })
            }
        } catch {
            failure = AppFailure(error, locale: locale)
        }
    }

    func pickAndImport(locale: Locale) async {
        let urls = DirectoryPicker.pickImageFiles(locale: locale)
        await importURLs(urls, locale: locale)
    }

    func reorder(in slot: Slot, from: Int, to: Int, locale: Locale) {
        let urls = photos(in: slot).map(\.url)
        ignoringWatcher = true
        defer { ignoringWatcher = false }
        do {
            try organizer.reorder(urls: urls, moving: from, to: to, project: project, slot: slot)
            reload()
            imageRevision += 1
        } catch {
            failure = AppFailure(error, locale: locale)
        }
    }

    func revealCurrent() {
        if let photo = currentTriagePhoto {
            FinderReveal.reveal(photo.url)
        } else {
            FinderReveal.reveal(project.url)
        }
    }

    func clearFailure() {
        failure = nil
    }

    func close() {
        watcher.stop()
        ThumbnailStore.shared.removeAll()
    }

    private func moveCurrent(to slot: Slot, locale: Locale) {
        guard let photo = currentTriagePhoto else { return }
        ignoringWatcher = true
        defer { ignoringWatcher = false }
        do {
            let record = try organizer.move(photo, to: slot, in: project)
            if record.from != record.to {
                undoStack.append(record)
            }
            let remainingID = nextPhotoID(after: photo)
            reload()
            if mode == .triage {
                let scope = currentTriageScopeSlot()
                let remaining = scope == nil ? inbox : photos(in: scope!)
                if remaining.isEmpty {
                    exitTriage()
                } else {
                    triagePhotos = remaining
                    if let remainingID, let index = remaining.firstIndex(where: { $0.id == remainingID }) {
                        triageIndex = index
                    } else {
                        triageIndex = min(triageIndex, remaining.count - 1)
                    }
                }
            }
            failure = nil
        } catch {
            failure = AppFailure(error, locale: locale)
        }
    }

    private func nextPhotoID(after photo: DiskPhoto) -> String? {
        guard let index = triagePhotos.firstIndex(of: photo) else { return nil }
        let next = index + 1
        if triagePhotos.indices.contains(next) { return triagePhotos[next].id }
        return nil
    }

    private func currentTriageScopeSlot() -> Slot? {
        guard let first = triagePhotos.first else { return project.map.inbox }
        if first.slotId == project.map.inbox?.id { return nil }
        return project.map.slot(id: first.slotId)
    }

    private func refreshTriageListKeepingCurrent() {
        let currentID = currentTriagePhoto?.id
        let scope = currentTriageScopeSlot()
        triagePhotos = scope == nil ? inbox : photos(in: scope!)
        if let currentID, let index = triagePhotos.firstIndex(where: { $0.id == currentID }) {
            triageIndex = index
        } else if triagePhotos.isEmpty {
            exitTriage()
        } else {
            triageIndex = min(triageIndex, triagePhotos.count - 1)
        }
    }

    private func startWatcher() {
        watcher.start(url: project.url) { [weak self] in
            Task { @MainActor in
                self?.scheduleReloadFromDisk()
            }
        }
    }

    private func scheduleReloadFromDisk() {
        guard !ignoringWatcher else { return }
        reloadTask?.cancel()
        reloadTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, !self.ignoringWatcher else { return }
            self.reload()
        }
    }
}
