import Foundation

struct FileOrganizer {
    var fileManager: FileManager = .default

    func move(
        _ photo: DiskPhoto,
        to slot: Slot,
        in project: OpenedProject
    ) throws -> UndoRecord {
        guard fileManager.fileExists(atPath: photo.url.path) else {
            throw OrganizerError.missingFile(photo.fileName)
        }
        let destinationFolder = project.folderURL(for: slot)
        try ensureFolder(destinationFolder)

        let destinationName: String
        if slot.isInbox {
            destinationName = uniqueJPEGName(preferred: photo.fileName, in: destinationFolder)
        } else {
            let index = try ProjectScanner.imageURLs(in: destinationFolder).count + 1
            destinationName = try FileNameFormatter.fileName(
                pattern: project.map.fileNamePattern,
                project: project.slug,
                slot: slot.folder,
                index: index
            )
        }

        var destination = destinationFolder.appendingPathComponent(destinationName)
        if destination.standardizedFileURL == photo.url.standardizedFileURL {
            return UndoRecord(from: photo.url, to: photo.url)
        }
        if fileManager.fileExists(atPath: destination.path) {
            destination = destinationFolder.appendingPathComponent(uniqueJPEGName(preferred: destinationName, in: destinationFolder))
        }

        do {
            try fileManager.moveItem(at: photo.url, to: destination)
        } catch {
            throw OrganizerError.moveFailed(error.localizedDescription)
        }
        return UndoRecord(from: photo.url, to: destination)
    }

    func undo(_ record: UndoRecord) throws {
        if record.from.standardizedFileURL == record.to.standardizedFileURL { return }
        guard fileManager.fileExists(atPath: record.to.path) else {
            throw OrganizerError.missingFile(record.to.lastPathComponent)
        }
        var destination = record.from
        if fileManager.fileExists(atPath: destination.path) {
            destination = record.from.deletingLastPathComponent()
                .appendingPathComponent(uniqueJPEGName(preferred: record.from.lastPathComponent, in: record.from.deletingLastPathComponent()))
        }
        do {
            try fileManager.moveItem(at: record.to, to: destination)
        } catch {
            throw OrganizerError.moveFailed(error.localizedDescription)
        }
    }

    func reorder(urls: [URL], moving from: Int, to destination: Int, project: OpenedProject, slot: Slot) throws {
        guard from != destination else { return }
        guard urls.indices.contains(from), destination >= 0, destination <= urls.count else {
            throw OrganizerError.invalidIndex
        }
        var ordered = urls
        let item = ordered.remove(at: from)
        let insertAt = destination > from ? destination - 1 : destination
        let clamped = min(max(insertAt, 0), ordered.count)
        ordered.insert(item, at: clamped)
        try renumber(urls: ordered, project: project, slot: slot)
    }

    func renumber(urls: [URL], project: OpenedProject, slot: Slot) throws {
        if slot.isInbox { return }
        let temps: [URL] = try urls.enumerated().map { index, url in
            guard fileManager.fileExists(atPath: url.path) else {
                throw OrganizerError.missingFile(url.lastPathComponent)
            }
            let temp = url.deletingLastPathComponent()
                .appendingPathComponent(".__fastreport_tmp_\(index)_\(UUID().uuidString).jpeg")
            try fileManager.moveItem(at: url, to: temp)
            return temp
        }
        for (index, temp) in temps.enumerated() {
            let name = try FileNameFormatter.fileName(
                pattern: project.map.fileNamePattern,
                project: project.slug,
                slot: slot.folder,
                index: index + 1
            )
            let final = temp.deletingLastPathComponent().appendingPathComponent(name)
            if fileManager.fileExists(atPath: final.path) {
                try fileManager.removeItem(at: final)
            }
            try fileManager.moveItem(at: temp, to: final)
        }
    }

    private func ensureFolder(_ url: URL) throws {
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            if !isDirectory.boolValue { throw OrganizerError.moveFailed(url.lastPathComponent) }
            return
        }
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            throw OrganizerError.moveFailed(error.localizedDescription)
        }
    }

    func uniqueJPEGName(preferred: String, in folder: URL) -> String {
        let stem = (preferred as NSString).deletingPathExtension
        let sanitized = stem.isEmpty ? "photo" : stem
        var attempt = 0
        while attempt < 10_000 {
            let name = attempt == 0 ? "\(sanitized).jpeg" : "\(sanitized)-\(attempt).jpeg"
            if !fileManager.fileExists(atPath: folder.appendingPathComponent(name).path) {
                return name
            }
            attempt += 1
        }
        return "\(UUID().uuidString).jpeg"
    }
}
