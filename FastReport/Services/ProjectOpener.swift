import Foundation

struct OpenedProject: Equatable, Sendable {
    var url: URL
    var metadata: ProjectMetadata
    var map: OrganizationMap
    var bookmarkData: Data?

    var slug: String {
        (try? ProjectSlug.make(from: metadata.displayName)) ?? "Project"
    }

    func folderURL(for slot: Slot) -> URL {
        url.appendingPathComponent(slot.folder, isDirectory: true)
    }

    func slot(containing file: URL) -> Slot? {
        let parent = file.deletingLastPathComponent().lastPathComponent
        return map.slot(folder: parent)
    }
}

enum ProjectOpener {
    static func open(url: URL, maps: [OrganizationMap]) throws -> OpenedProject {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ProjectOpenError.inaccessible
        }

        guard let metadataURL = ProjectMetadata.fileURL(in: url) else {
            throw ProjectOpenError.missingMetadata
        }

        let metadataData: Data
        let metadata: ProjectMetadata
        do {
            metadataData = try Data(contentsOf: metadataURL)
            metadata = try ProjectMetadata.decode(from: metadataData)
        } catch {
            throw ProjectOpenError.missingMetadata
        }

        let visibleURL = url.appendingPathComponent(ProjectMetadata.fileName)
        if metadataURL.lastPathComponent == ProjectMetadata.legacyFileName,
           !FileManager.default.fileExists(atPath: visibleURL.path) {
            try? metadataData.write(to: visibleURL, options: [.atomic])
        }

        guard let map = maps.first(where: { $0.id == metadata.mapId }) else {
            throw ProjectOpenError.missingMap(metadata.mapId)
        }
        try MapValidator.validate(map)
        return OpenedProject(url: url.standardizedFileURL, metadata: metadata, map: map, bookmarkData: nil)
    }
}
