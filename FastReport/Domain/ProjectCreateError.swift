import Foundation

enum ProjectCreateError: Error, Equatable {
    case invalidMap
    case parentMissing
    case parentNotDirectory
    case parentInaccessible
    case alreadyExists(String)
    case createFailed(String)
    case writeMetadataFailed(String)

    var code: String {
        switch self {
        case .invalidMap: "project.create.map"
        case .parentMissing: "project.create.parent_missing"
        case .parentNotDirectory: "project.create.parent_type"
        case .parentInaccessible: "project.create.parent_access"
        case .alreadyExists: "project.create.exists"
        case .createFailed: "project.create.failed"
        case .writeMetadataFailed: "project.create.metadata"
        }
    }

    func localized(locale: Locale) -> String {
        switch self {
        case .invalidMap:
            String(localized: "error.project.create.map", locale: locale)
        case .parentMissing:
            String(localized: "error.project.create.parent_missing", locale: locale)
        case .parentNotDirectory:
            String(localized: "error.project.create.parent_type", locale: locale)
        case .parentInaccessible:
            String(localized: "error.project.create.parent_access", locale: locale)
        case .alreadyExists:
            String(localized: "error.project.create.exists", locale: locale)
        case .createFailed:
            String(localized: "error.project.create.failed", locale: locale)
        case .writeMetadataFailed:
            String(localized: "error.project.create.metadata", locale: locale)
        }
    }
}

struct CreatedProject: Equatable, Sendable {
    let url: URL
    let metadata: ProjectMetadata
    let bookmarkData: Data?
    let bookmarkWarning: AppFailure?
}
