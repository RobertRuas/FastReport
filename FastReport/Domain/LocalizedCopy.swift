import Foundation

/// Texto de mapa com português e inglês obrigatórios.
struct LocalizedCopy: Codable, Equatable, Sendable, Hashable {
    var pt: String
    var en: String

    func resolved(language: AppLanguage) -> String {
        let value: String
        switch language {
        case .portuguese:
            value = pt
        case .english:
            value = en
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let fallbackPT = pt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !fallbackPT.isEmpty { return fallbackPT }
        let fallbackEN = en.trimmingCharacters(in: .whitespacesAndNewlines)
        return fallbackEN
    }
}

enum LocalizedCopyError: Equatable {
    case missingBoth
}

extension LocalizedCopy {
    func validated() -> LocalizedCopyError? {
        let ptEmpty = pt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let enEmpty = en.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if ptEmpty && enEmpty { return .missingBoth }
        return nil
    }
}
