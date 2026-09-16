import Foundation
import Observation

@MainActor
@Observable
final class ImageSettingsStore {
    static let maxKey = "fastreport.image.maxDimension"
    static let qualityKey = "fastreport.image.quality"

    private let defaults: UserDefaults
    var settings: ImageExportSettings

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let maxDimension = defaults.object(forKey: Self.maxKey) as? Int ?? ImageExportSettings.default.maxDimension
        let quality = defaults.object(forKey: Self.qualityKey) as? Double ?? ImageExportSettings.default.quality
        let raw = ImageExportSettings(maxDimension: maxDimension, quality: quality)
        self.settings = (try? raw.validated()) ?? .default
    }

    func setMaxDimension(_ value: Int) {
        let next = ImageExportSettings(maxDimension: value, quality: settings.quality)
        settings = (try? next.validated()) ?? settings
        defaults.set(settings.maxDimension, forKey: Self.maxKey)
    }

    func setQuality(_ value: Double) {
        let next = ImageExportSettings(maxDimension: settings.maxDimension, quality: value)
        settings = (try? next.validated()) ?? settings
        defaults.set(settings.quality, forKey: Self.qualityKey)
    }
}
