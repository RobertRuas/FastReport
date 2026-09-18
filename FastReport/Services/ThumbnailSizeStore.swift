import Foundation
import Observation

enum ThumbnailSizeMode: String, Equatable {
    case automatic
    case manual
}

@MainActor
@Observable
final class ThumbnailSizeStore {
    static let modeKey = "fastreport.thumbs.mode"
    static let stepKey = "fastreport.thumbs.step"
    static let spacing: CGFloat = 8
    static let steps: [CGFloat] = [52, 64, 80, 104, 132]
    static let minSize: CGFloat = 52
    static let maxSize: CGFloat = 132
    private static let visibleInAutomatic: CGFloat = 8

    private let defaults: UserDefaults
    var mode: ThumbnailSizeMode
    var stepIndex: Int

    var layoutWidth: CGFloat = 800
    var layoutPhotoCount: Int = 0

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.string(forKey: Self.modeKey) == ThumbnailSizeMode.manual.rawValue {
            mode = .manual
        } else {
            mode = .automatic
        }
        let stored = defaults.object(forKey: Self.stepKey) as? Int ?? 2
        stepIndex = min(max(stored, 0), Self.steps.count - 1)
    }

    var resolvedSize: CGFloat {
        size(containerWidth: layoutWidth, photoCount: layoutPhotoCount)
    }

    func updateLayout(width: CGFloat, photoCount: Int) {
        if abs(layoutWidth - width) > 0.5 {
            layoutWidth = width
        }
        if layoutPhotoCount != photoCount {
            layoutPhotoCount = photoCount
        }
    }

    func size(containerWidth: CGFloat, photoCount: Int = 0) -> CGFloat {
        switch mode {
        case .automatic:
            Self.automaticSize(containerWidth: containerWidth, photoCount: photoCount)
        case .manual:
            Self.steps[min(max(stepIndex, 0), Self.steps.count - 1)]
        }
    }

    static func automaticSize(containerWidth: CGFloat, photoCount: Int = 0) -> CGFloat {
        let width = max(containerWidth, 1)
        let raw = (width - spacing * (visibleInAutomatic - 1)) / visibleInAutomatic
        let byWindow = min(maxSize, max(minSize, raw.rounded()))
        guard photoCount > 1 else { return byWindow }
        let fitted = (width - spacing * CGFloat(photoCount - 1)) / CGFloat(photoCount)
        let byCount = min(maxSize, max(minSize, fitted.rounded()))
        return min(byWindow, byCount)
    }

    func makeSmaller(currentSize: CGFloat) {
        let current = nearestStepIndex(for: currentSize)
        stepIndex = max(0, current - 1)
        mode = .manual
        persist()
    }

    func makeLarger(currentSize: CGFloat) {
        let current = nearestStepIndex(for: currentSize)
        stepIndex = min(Self.steps.count - 1, current + 1)
        mode = .manual
        persist()
    }

    func useAutomatic() {
        mode = .automatic
        persist()
    }

    var canShrink: Bool {
        if mode == .automatic { return true }
        return stepIndex > 0
    }

    var canGrow: Bool {
        if mode == .automatic { return true }
        return stepIndex < Self.steps.count - 1
    }

    private func nearestStepIndex(for size: CGFloat) -> Int {
        let distances = Self.steps.enumerated().map { index, step in
            (index, abs(step - size))
        }
        return distances.min { $0.1 < $1.1 }?.0 ?? 2
    }

    private func persist() {
        defaults.set(mode.rawValue, forKey: Self.modeKey)
        defaults.set(stepIndex, forKey: Self.stepKey)
    }
}
