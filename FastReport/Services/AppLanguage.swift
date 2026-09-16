import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case portuguese = "pt"
    case english = "en"

    var id: String { rawValue }

    var locale: Locale {
        switch self {
        case .portuguese: Locale(identifier: "pt")
        case .english: Locale(identifier: "en")
        }
    }

    var displayKey: String {
        switch self {
        case .portuguese: "settings.language.portuguese"
        case .english: "settings.language.english"
        }
    }

    static func resolved(stored: String?) -> AppLanguage {
        guard let stored else { return .portuguese }
        let normalized = stored.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty { return .portuguese }
        if normalized == "pt" || normalized.hasPrefix("pt-") || normalized.hasPrefix("pt_") {
            return .portuguese
        }
        if normalized == "en" || normalized.hasPrefix("en-") || normalized.hasPrefix("en_") {
            return .english
        }
        return .portuguese
    }
}
