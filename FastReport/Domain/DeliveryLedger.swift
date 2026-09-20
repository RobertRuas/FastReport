import Foundation

struct DeliveryLedger: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1
    static let fileName = "fastreport-delivery.json"

    var schemaVersion: Int
    var placedIDs: [String]
    var placedPaths: [String]

    init(schemaVersion: Int = currentSchemaVersion, placedIDs: [String] = [], placedPaths: [String] = []) {
        self.schemaVersion = schemaVersion
        self.placedIDs = placedIDs
        self.placedPaths = placedPaths
    }

    var idSet: Set<String> { Set(placedIDs) }
    var pathSet: Set<String> { Set(placedPaths) }

    func contains(_ photo: DiskPhoto, projectURL: URL) -> Bool {
        if idSet.contains(photo.id) { return true }
        return pathSet.contains(Self.relativePath(for: photo.url, projectURL: projectURL))
    }

    func toggling(_ photo: DiskPhoto, projectURL: URL) -> DeliveryLedger {
        if contains(photo, projectURL: projectURL) {
            return removing(photo, projectURL: projectURL)
        }
        return placing(photo, projectURL: projectURL)
    }

    func placing(_ photo: DiskPhoto, projectURL: URL) -> DeliveryLedger {
        var copy = self
        let path = Self.relativePath(for: photo.url, projectURL: projectURL)
        if !copy.placedIDs.contains(photo.id) {
            copy.placedIDs.append(photo.id)
        }
        if !copy.placedPaths.contains(path) {
            copy.placedPaths.append(path)
        }
        return copy
    }

    func removing(_ photo: DiskPhoto, projectURL: URL) -> DeliveryLedger {
        var copy = self
        let path = Self.relativePath(for: photo.url, projectURL: projectURL)
        copy.placedIDs.removeAll { $0 == photo.id }
        copy.placedPaths.removeAll { $0 == path }
        return copy
    }

    func refreshing(to photos: [DiskPhoto], projectURL: URL) -> DeliveryLedger {
        var copy = DeliveryLedger(schemaVersion: schemaVersion)
        for photo in photos where contains(photo, projectURL: projectURL) {
            copy = copy.placing(photo, projectURL: projectURL)
        }
        return copy
    }

    static func relativePath(for url: URL, projectURL: URL) -> String {
        let file = url.standardizedFileURL.path
        let root = projectURL.standardizedFileURL.path
        if file.hasPrefix(root + "/") {
            return String(file.dropFirst(root.count + 1))
        }
        return url.lastPathComponent
    }

    static func fileURL(in projectURL: URL) -> URL {
        projectURL.appendingPathComponent(fileName)
    }

    static func load(from projectURL: URL, fileManager: FileManager = .default) -> DeliveryLedger {
        let url = fileURL(in: projectURL)
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(DeliveryLedger.self, from: data)
        else {
            return DeliveryLedger()
        }
        return decoded
    }

    func save(in projectURL: URL, fileManager: FileManager = .default) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: Self.fileURL(in: projectURL), options: [.atomic])
    }
}
