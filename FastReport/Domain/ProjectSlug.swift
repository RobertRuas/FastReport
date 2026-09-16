import Foundation

enum ProjectSlugError: Error, Equatable {
    case empty
    case invalid

    var code: String {
        switch self {
        case .empty: "slug.empty"
        case .invalid: "slug.invalid"
        }
    }

    func localized(locale: Locale) -> String {
        String(localized: "error.slug", locale: locale)
    }
}

enum ProjectSlug {
    static func make(from displayName: String) throws -> String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { throw ProjectSlugError.empty }

        let folded = trimmed.folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US_POSIX"))
        var scalarBuffer: [Character] = []
        scalarBuffer.reserveCapacity(folded.count)

        var lastWasSeparator = false
        for character in folded {
            if character.isLetter || character.isNumber {
                scalarBuffer.append(character)
                lastWasSeparator = false
            } else if !lastWasSeparator && !scalarBuffer.isEmpty {
                scalarBuffer.append("_")
                lastWasSeparator = true
            }
        }

        while scalarBuffer.last == "_" {
            scalarBuffer.removeLast()
        }

        let slug = String(scalarBuffer)
        if slug.isEmpty { throw ProjectSlugError.invalid }
        if slug.hasPrefix(".") { throw ProjectSlugError.invalid }
        return slug
    }
}
