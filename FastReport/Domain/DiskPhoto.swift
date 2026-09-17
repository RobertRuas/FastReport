import Foundation

struct DiskPhoto: Equatable, Identifiable, Hashable, Sendable {
    let id: String
    let url: URL
    let slotId: String
    let fileName: String

    init(url: URL, slotId: String, fileName: String, id: String? = nil) {
        self.id = id ?? DiskPhoto.stableID(for: url)
        self.url = url
        self.slotId = slotId
        self.fileName = fileName
    }

    static func stableID(for url: URL) -> String {
        if let number = try? FileManager.default.attributesOfItem(atPath: url.path)[.systemFileNumber] as? UInt64, number > 0 {
            return "inode-\(number)"
        }
        return url.standardizedFileURL.path
    }
}

struct UndoRecord: Equatable, Sendable {
    let from: URL
    let to: URL
}

struct ImportStats: Equatable, Sendable {
    var attempted = 0
    var imported = 0
    var converted = 0
    var alreadyJPEG = 0
    var skipped = 0
    var failed: [String] = []

    var hasFailures: Bool { !failed.isEmpty }
}

enum OrganizerError: Error, Equatable {
    case missingFile(String)
    case missingSlot
    case missingTrash
    case destinationExists(String)
    case moveFailed(String)
    case nothingToUndo
    case invalidIndex

    var code: String {
        switch self {
        case .missingFile: "organizer.missing"
        case .missingSlot: "organizer.slot"
        case .missingTrash: "organizer.trash"
        case .destinationExists: "organizer.exists"
        case .moveFailed: "organizer.move"
        case .nothingToUndo: "organizer.undo.empty"
        case .invalidIndex: "organizer.index"
        }
    }

    func localized(locale: Locale) -> String {
        switch self {
        case .missingFile:
            String(localized: "error.organizer.missing", locale: locale)
        case .missingSlot, .missingTrash:
            String(localized: "error.organizer.slot", locale: locale)
        case .destinationExists:
            String(localized: "error.organizer.exists", locale: locale)
        case .moveFailed:
            String(localized: "error.organizer.move", locale: locale)
        case .nothingToUndo:
            String(localized: "error.organizer.undo.empty", locale: locale)
        case .invalidIndex:
            String(localized: "error.organizer.index", locale: locale)
        }
    }
}

enum ProjectOpenError: Error, Equatable {
    case missingMetadata
    case missingMap(String)
    case inaccessible

    var code: String {
        switch self {
        case .missingMetadata: "project.open.metadata"
        case .missingMap: "project.open.map"
        case .inaccessible: "project.open.access"
        }
    }

    func localized(locale: Locale) -> String {
        switch self {
        case .missingMetadata:
            String(localized: "error.project.open.metadata", locale: locale)
        case .missingMap:
            String(localized: "error.project.open.map", locale: locale)
        case .inaccessible:
            String(localized: "error.project.open.access", locale: locale)
        }
    }
}

enum ProjectDeleteError: Error, Equatable {
    case notAProject
    case failed

    var code: String {
        switch self {
        case .notAProject: "project.delete.not_project"
        case .failed: "project.delete.failed"
        }
    }

    func localized(locale: Locale) -> String {
        switch self {
        case .notAProject:
            String(localized: "error.project.delete.not_project", locale: locale)
        case .failed:
            String(localized: "error.project.delete.failed", locale: locale)
        }
    }
}
