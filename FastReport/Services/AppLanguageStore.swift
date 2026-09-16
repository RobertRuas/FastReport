import Foundation
import Observation

@MainActor
@Observable
final class AppLanguageStore {
    static let storageKey = "fastreport.language"

    private let defaults: UserDefaults
    private(set) var language: AppLanguage

    var locale: Locale { language.locale }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.language = AppLanguage.resolved(stored: defaults.string(forKey: Self.storageKey))
        persistIfNeeded()
    }

    func setLanguage(_ language: AppLanguage) {
        self.language = language
        defaults.set(language.rawValue, forKey: Self.storageKey)
    }

    private func persistIfNeeded() {
        if defaults.string(forKey: Self.storageKey) == nil {
            defaults.set(language.rawValue, forKey: Self.storageKey)
        }
    }
}
