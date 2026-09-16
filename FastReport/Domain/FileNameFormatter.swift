import Foundation

enum FileNameError: Error, Equatable {
    case emptyProject
    case emptySlot
    case invalidIndex(Int)
    case emptyPattern
    case missingToken(String)
    case unsafeCharacters

    var code: String {
        switch self {
        case .emptyProject: "filename.project"
        case .emptySlot: "filename.slot"
        case .invalidIndex: "filename.index"
        case .emptyPattern: "filename.pattern"
        case .missingToken: "filename.token"
        case .unsafeCharacters: "filename.unsafe"
        }
    }

    func localized(locale: Locale) -> String {
        String(localized: "error.filename", locale: locale)
    }
}

enum FileNameFormatter {
    static func fileName(pattern: String, project: String, slot: String, index: Int) throws -> String {
        let pattern = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        let project = project.trimmingCharacters(in: .whitespacesAndNewlines)
        let slot = slot.trimmingCharacters(in: .whitespacesAndNewlines)

        if pattern.isEmpty { throw FileNameError.emptyPattern }
        if project.isEmpty { throw FileNameError.emptyProject }
        if slot.isEmpty { throw FileNameError.emptySlot }
        if index < 1 { throw FileNameError.invalidIndex(index) }

        for token in MapValidator.requiredPatternTokens where !pattern.contains(token) {
            throw FileNameError.missingToken(token)
        }

        let result = pattern
            .replacingOccurrences(of: "{project}", with: project)
            .replacingOccurrences(of: "{slot}", with: slot)
            .replacingOccurrences(of: "{index}", with: String(index))

        if result.contains("/") || result.contains("\\") || result.contains(":") || result.contains("\0") {
            throw FileNameError.unsafeCharacters
        }
        return result
    }
}
