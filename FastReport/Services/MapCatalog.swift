import Foundation

enum MapCatalogError: Error, Equatable {
    case mapsDirectoryMissing
    case noValidMaps([String])
    case unreadable(String, String)
    case decodingFailed(String, String)
    case invalid(String, String)

    var code: String {
        switch self {
        case .mapsDirectoryMissing: "maps.missing"
        case .noValidMaps: "maps.empty"
        case .unreadable: "maps.unreadable"
        case .decodingFailed: "maps.decoding"
        case .invalid: "maps.invalid"
        }
    }

    func localized(locale: Locale) -> String {
        switch self {
        case .mapsDirectoryMissing:
            String(localized: "error.maps.missing", locale: locale)
        case .noValidMaps:
            String(localized: "error.maps.empty", locale: locale)
        case .unreadable:
            String(localized: "error.maps.unreadable", locale: locale)
        case .decodingFailed:
            String(localized: "error.maps.decoding", locale: locale)
        case .invalid:
            String(localized: "error.maps.invalid_file", locale: locale)
        }
    }
}

struct MapLoadResult: Equatable, Sendable {
    var maps: [OrganizationMap]
    var skipped: [AppFailure]
}

enum MapCatalog {
    private static let subdirectory = "Maps"

    static func loadBundled(from bundle: Bundle) throws -> MapLoadResult {
        let urls = try mapFileURLs(in: bundle)
        return try load(from: urls)
    }

    static func load(from directory: URL) throws -> MapLoadResult {
        let files: [URL]
        do {
            files = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            throw MapCatalogError.unreadable(directory.lastPathComponent, error.localizedDescription)
        }
        let jsonFiles = files.filter { $0.pathExtension.lowercased() == "json" }
        if jsonFiles.isEmpty {
            throw MapCatalogError.noValidMaps(["no-json-in-\(directory.lastPathComponent)"])
        }
        return try load(from: jsonFiles)
    }

    static func load(from files: [URL]) throws -> MapLoadResult {
        if files.isEmpty {
            throw MapCatalogError.mapsDirectoryMissing
        }

        var maps: [OrganizationMap] = []
        var skipped: [AppFailure] = []
        var seenIds = Set<String>()

        for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            do {
                let map = try decodeAndValidate(file: file)
                if !seenIds.insert(map.id).inserted {
                    skipped.append(
                        AppFailure(
                            code: "maps.duplicate_id",
                            message: String(localized: "error.maps.duplicate", locale: Locale(identifier: "pt")),
                            debugDescription: map.id
                        )
                    )
                    continue
                }
                maps.append(map)
            } catch {
                skipped.append(AppFailure(error))
            }
        }

        if maps.isEmpty {
            throw MapCatalogError.noValidMaps(skipped.map(\.code))
        }
        return MapLoadResult(maps: maps, skipped: skipped)
    }

    static func decodeAndValidate(file: URL) throws -> OrganizationMap {
        let data: Data
        do {
            data = try Data(contentsOf: file)
        } catch {
            throw MapCatalogError.unreadable(file.lastPathComponent, error.localizedDescription)
        }
        if data.isEmpty {
            throw MapCatalogError.decodingFailed(file.lastPathComponent, "empty")
        }

        let map: OrganizationMap
        do {
            map = try JSONDecoder().decode(OrganizationMap.self, from: data)
        } catch {
            throw MapCatalogError.decodingFailed(file.lastPathComponent, error.localizedDescription)
        }

        do {
            try MapValidator.validate(map)
        } catch let error as MapValidationError {
            throw MapCatalogError.invalid(file.lastPathComponent, error.issues.map(\.rawMessage).joined(separator: "; "))
        }

        return map
    }

    static func mapFileURLs(in bundle: Bundle) throws -> [URL] {
        if let directory = bundle.url(forResource: subdirectory, withExtension: nil) {
            let files = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            let json = files.filter { $0.pathExtension.lowercased() == "json" }
            if !json.isEmpty { return json }
        }

        if let rootFiles = bundle.urls(forResourcesWithExtension: "json", subdirectory: subdirectory), !rootFiles.isEmpty {
            return rootFiles
        }

        if let named = bundle.url(forResource: "inspection-t24", withExtension: "json", subdirectory: subdirectory) {
            return [named]
        }

        if let named = bundle.url(forResource: "inspection-t24", withExtension: "json") {
            return [named]
        }

        if let rootFiles = bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) {
            let maps = rootFiles.filter { $0.lastPathComponent != "Contents.json" }
            if !maps.isEmpty { return maps }
        }

        throw MapCatalogError.mapsDirectoryMissing
    }
}
