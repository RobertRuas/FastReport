import Foundation

enum ProjectScanner {
    static func photos(in project: OpenedProject) throws -> [DiskPhoto] {
        var result: [DiskPhoto] = []
        for slot in project.map.slots {
            let folder = project.folderURL(for: slot)
            let urls = try imageURLs(in: folder)
            for url in urls {
                result.append(DiskPhoto(url: url, slotId: slot.id, fileName: url.lastPathComponent))
            }
        }
        return result
    }

    static func imageURLs(in folder: URL) throws -> [URL] {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return []
        }
        let items: [URL]
        do {
            items = try FileManager.default.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            throw OrganizerError.moveFailed(error.localizedDescription)
        }
        return items
            .filter { ImageFile.isSupported($0) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }
}
