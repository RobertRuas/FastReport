import Foundation

enum ProjectFolderNameError: Error, Equatable {
    case empty
    case invalid
    case tooLong

    var code: String {
        switch self {
        case .empty: "project.folder.empty"
        case .invalid: "project.folder.invalid"
        case .tooLong: "project.folder.too_long"
        }
    }

    func localized(locale: Locale) -> String {
        switch self {
        case .empty:
            String(localized: "error.project.folder.empty", locale: locale)
        case .invalid:
            String(localized: "error.project.folder.invalid", locale: locale)
        case .tooLong:
            String(localized: "error.project.folder.too_long", locale: locale)
        }
    }
}

enum ProjectFolderName {
    static let maxLength = 255

    static func validate(_ displayName: String) throws -> String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { throw ProjectFolderNameError.empty }
        if trimmed.count > maxLength { throw ProjectFolderNameError.tooLong }
        if !MapValidator.isSafeFolderName(trimmed) { throw ProjectFolderNameError.invalid }
        if trimmed.hasSuffix(".") { throw ProjectFolderNameError.invalid }
        return trimmed
    }
}
