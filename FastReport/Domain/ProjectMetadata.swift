import Foundation

struct ProjectMetadata: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1
    static let fileName = ".fastreport.json"

    var schemaVersion: Int
    var mapId: String
    var displayName: String
    var createdAt: Date

    init(schemaVersion: Int = ProjectMetadata.currentSchemaVersion, mapId: String, displayName: String, createdAt: Date) {
        self.schemaVersion = schemaVersion
        self.mapId = mapId
        self.displayName = displayName
        self.createdAt = createdAt
    }

    func validated() throws -> ProjectMetadata {
        if schemaVersion < 1 {
            throw ProjectMetadataError.invalidSchemaVersion(schemaVersion)
        }
        if schemaVersion > Self.currentSchemaVersion {
            throw ProjectMetadataError.unsupportedSchemaVersion(schemaVersion)
        }
        let mapId = mapId.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if mapId.isEmpty {
            throw ProjectMetadataError.emptyMapId
        }
        if displayName.isEmpty {
            throw ProjectMetadataError.emptyDisplayName
        }
        var copy = self
        copy.mapId = mapId
        copy.displayName = displayName
        return copy
    }

    static func decode(from data: Data, decoder: JSONDecoder = ProjectMetadata.makeDecoder()) throws -> ProjectMetadata {
        let metadata: ProjectMetadata
        do {
            metadata = try decoder.decode(ProjectMetadata.self, from: data)
        } catch {
            throw ProjectMetadataError.decodingFailed(error.localizedDescription)
        }
        return try metadata.validated()
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

enum ProjectMetadataError: Error, Equatable {
    case invalidSchemaVersion(Int)
    case unsupportedSchemaVersion(Int)
    case emptyMapId
    case emptyDisplayName
    case decodingFailed(String)

    var code: String {
        switch self {
        case .invalidSchemaVersion: "project.schema.invalid"
        case .unsupportedSchemaVersion: "project.schema.unsupported"
        case .emptyMapId: "project.map_id.empty"
        case .emptyDisplayName: "project.name.empty"
        case .decodingFailed: "project.decoding"
        }
    }

    func localized(locale: Locale) -> String {
        switch self {
        case .invalidSchemaVersion, .unsupportedSchemaVersion:
            String(localized: "error.project.schema", locale: locale)
        case .emptyMapId:
            String(localized: "error.project.map_id", locale: locale)
        case .emptyDisplayName:
            String(localized: "error.project.name", locale: locale)
        case .decodingFailed:
            String(localized: "error.project.decoding", locale: locale)
        }
    }
}
