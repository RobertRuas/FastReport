import AppKit
import Foundation
import Observation

enum WorkspaceMode: Equatable {
    case gallery
    case triage
    case delivery
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
    private(set) var deliveryLedger = DeliveryLedger()

    var settings: ImageExportSettings
    private let organizer: FileOrganizer
    private let watcher = FolderWatcher()
    private var ignoringWatcher = false
    private var reloadTask: Task<Void, Never>?

    init(project: OpenedProject, settings: ImageExportSettings = .default, organizer: FileOrganizer = FileOrganizer()) {
        self.project = project
        self.settings = settings
        self.organizer = organizer
        deliveryLedger = DeliveryLedger.load(from: project.url)
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
    var hasTrashItems: Bool {
        guard let trash = project.map.trash else { return false }
        return photos.contains { $0.slotId == trash.id }
    }

    var placedCount: Int {
        photos.filter { photo in
            guard isPlaced(photo), let slot = project.map.slot(id: photo.slotId) else { return false }
            return !slot.isInbox && !slot.isTrash
        }.count
    }

    func isPlaced(_ photo: DiskPhoto) -> Bool {
        deliveryLedger.contains(photo, projectURL: project.url)
    }

    func deliverySlotPartitions() -> (special: [Slot], regular: [Slot]) {
        ReviewDisplaySlots.deliveryPartitions(map: project.map, occupiedIds: occupiedSlotIDs)
    }

    func deliveryDisplaySlots() -> [Slot] {
        ReviewDisplaySlots.deliveryOrdered(map: project.map, occupiedIds: occupiedSlotIDs)
    }

    func toggleDelivery() {
        mode = mode == .delivery ? .gallery : .delivery
    }

    func markPlaced(_ photo: DiskPhoto) {
        persistLedger(deliveryLedger.placing(photo, projectURL: project.url))
    }

    func togglePlaced(_ photo: DiskPhoto) {
        persistLedger(deliveryLedger.toggling(photo, projectURL: project.url))
    }

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
        ReviewDisplaySlots.ordered(map: project.map, occupiedIds: occupiedSlotIDs)
    }

    func reviewSlotPartitions() -> (special: [Slot], regular: [Slot]) {
        ReviewDisplaySlots.partitions(map: project.map, occupiedIds: occupiedSlotIDs)
    }

    private var occupiedSlotIDs: Set<String> {
        Set(photos.map(\.slotId))
    }

    func reload() {
        do {
            photos = try ProjectScanner.photos(in: project)
            deliveryLedger = deliveryLedger.refreshing(to: photos, projectURL: project.url)
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
        guard let photo = currentTriagePhoto else { return }
        trash(photo, locale: locale)
    }

    func trash(_ photo: DiskPhoto, locale: Locale) {
        guard let trash = project.map.trash else {
            failure = AppFailure(OrganizerError.missingTrash, locale: locale)
            return
        }
        if photo.slotId == trash.id { return }
        move(photo, to: trash, locale: locale)
    }

    func emptyTrash(locale: Locale) {
        guard let trash = project.map.trash else {
            failure = AppFailure(OrganizerError.missingTrash, locale: locale)
            return
        }
        let items = photos(in: trash)
        guard !items.isEmpty else { return }
        ignoringWatcher = true
        defer { ignoringWatcher = false }
        do {
            try organizer.emptyTrash(items)
            let emptied = Set(items.map { $0.url.standardizedFileURL.path })
            undoStack.removeAll { record in
                emptied.contains(record.from.standardizedFileURL.path)
                    || emptied.contains(record.to.standardizedFileURL.path)
            }
            ThumbnailStore.shared.removeAll()
            imageRevision += 1
            if mode == .triage, triagePhotos.contains(where: { emptied.contains($0.url.standardizedFileURL.path) }) {
                exitTriage()
            }
            reload()
            failure = nil
        } catch {
            failure = AppFailure(error, locale: locale)
            reload()
        }
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
        rotate(photo, locale: locale)
    }

    func rotate(_ photo: DiskPhoto, locale: Locale) {
        rewrite(photo, locale: locale) { url, settings in
            try ImagePipeline.rotateClockwise(at: url, settings: settings)
        }
    }

    func flipCurrent(locale: Locale) {
        rewriteCurrent(locale: locale) { url, settings in
            try ImagePipeline.flipHorizontal(at: url, settings: settings)
        }
    }

    func cropCurrent(normalized: CGRect, locale: Locale) {
        rewriteCurrent(locale: locale) { url, settings in
            try ImagePipeline.crop(at: url, normalized: normalized, settings: settings)
        }
    }

    func flipPending(locale: Locale) {
        let targets = inbox
        guard !targets.isEmpty else { return }
        ignoringWatcher = true
        defer { ignoringWatcher = false }
        var firstError: Error?
        for photo in targets {
            do {
                try ImagePipeline.flipHorizontal(at: photo.url, settings: settings)
            } catch {
                if firstError == nil { firstError = error }
            }
        }
        ThumbnailStore.shared.removeAll()
        imageRevision += 1
        if let firstError {
            failure = AppFailure(firstError, locale: locale)
        } else {
            failure = nil
        }
    }

    private func rewriteCurrent(locale: Locale, transform: (URL, ImageExportSettings) throws -> Void) {
        guard let photo = currentTriagePhoto else { return }
        rewrite(photo, locale: locale, transform: transform)
    }

    private func rewrite(_ photo: DiskPhoto, locale: Locale, transform: (URL, ImageExportSettings) throws -> Void) {
        ignoringWatcher = true
        defer { ignoringWatcher = false }
        do {
            try transform(photo.url, settings)
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

    private func persistLedger(_ ledger: DeliveryLedger) {
        deliveryLedger = ledger
        try? ledger.save(in: project.url)
    }

    private func moveCurrent(to slot: Slot, locale: Locale) {
        guard let photo = currentTriagePhoto else { return }
        move(photo, to: slot, locale: locale)
    }

    private func move(_ photo: DiskPhoto, to slot: Slot, locale: Locale) {
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
