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

        let metadataURL = url.appendingPathComponent(ProjectMetadata.fileName)
        guard FileManager.default.fileExists(atPath: metadataURL.path) else {
            throw ProjectOpenError.missingMetadata
        }

        let metadata: ProjectMetadata
        do {
            metadata = try ProjectMetadata.decode(from: Data(contentsOf: metadataURL))
        } catch {
            throw ProjectOpenError.missingMetadata
        }

        guard let map = maps.first(where: { $0.id == metadata.mapId }) else {
            throw ProjectOpenError.missingMap(metadata.mapId)
        }
        try MapValidator.validate(map)
        return OpenedProject(url: url.standardizedFileURL, metadata: metadata, map: map, bookmarkData: nil)
    }
}
