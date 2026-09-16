import Foundation

struct PhotoImporter {
    var settings: ImageExportSettings = .default
    var fileManager: FileManager = .default
    var organizer = FileOrganizer()

    func collectImages(from urls: [URL]) -> [URL] {
        var images: [URL] = []
        var seen = Set<String>()
        for url in urls {
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            for file in expand(url, depth: 0) {
                let key = file.standardizedFileURL.path
                if seen.insert(key).inserted {
                    images.append(file)
                }
            }
        }
        return images
    }

    func importFiles(_ urls: [URL], into project: OpenedProject) -> ImportStats {
        var stats = ImportStats()
        guard let inbox = project.map.inbox else {
            stats.failed.append("Inbox")
            return stats
        }
        let inboxFolder = project.folderURL(for: inbox)
        let images = collectImages(from: urls)
        stats.skipped = urls.reduce(0) { $0 + countUnsupported($1, depth: 0) }

        if images.isEmpty {
            stats.attempted = stats.skipped
            return stats
        }

        for source in images {
            stats.attempted += 1
            let accessed = source.startAccessingSecurityScopedResource()
            defer { if accessed { source.stopAccessingSecurityScopedResource() } }

            let preferred = source.deletingPathExtension().lastPathComponent + ".jpeg"
            let destination = inboxFolder.appendingPathComponent(
                organizer.uniqueJPEGName(preferred: preferred, in: inboxFolder)
            )
            do {
                try ImagePipeline.convertToJPEG(source: source, destination: destination, settings: settings)
                stats.imported += 1
                if ImageFile.isJPEG(source) {
                    stats.alreadyJPEG += 1
                } else {
                    stats.converted += 1
                }
            } catch {
                stats.failed.append(source.lastPathComponent)
                try? fileManager.removeItem(at: destination)
            }
        }
        return stats
    }

    private func expand(_ url: URL, depth: Int) -> [URL] {
        if depth > 3 { return [] }
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return [] }
        if isDirectory.boolValue {
            let children = (try? fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )) ?? []
            return children.flatMap { expand($0, depth: depth + 1) }
        }
        return ImageFile.isSupported(url) ? [url] : []
    }

    private func countUnsupported(_ url: URL, depth: Int) -> Int {
        if depth > 3 { return 0 }
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return 0 }
        if isDirectory.boolValue {
            let children = (try? fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )) ?? []
            return children.reduce(0) { $0 + countUnsupported($1, depth: depth + 1) }
        }
        return ImageFile.isSupported(url) ? 0 : 1
    }
}
