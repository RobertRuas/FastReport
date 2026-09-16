import Foundation

enum AppVersion {
    static func marketing(from bundle: Bundle = .main) -> String {
        marketing(info: bundle.infoDictionary ?? [:])
    }

    static func build(from bundle: Bundle = .main) -> String {
        build(info: bundle.infoDictionary ?? [:])
    }

    static func display(from bundle: Bundle = .main) -> String {
        display(info: bundle.infoDictionary ?? [:])
    }

    static func marketing(info: [String: Any]) -> String {
        nonEmpty(info["CFBundleShortVersionString"]) ?? "0.0.0"
    }

    static func build(info: [String: Any]) -> String {
        nonEmpty(info["CFBundleVersion"]) ?? "0"
    }

    static func display(info: [String: Any]) -> String {
        "\(marketing(info: info)) (\(build(info: info)))"
    }

    private static func nonEmpty(_ value: Any?) -> String? {
        if let number = value as? NSNumber {
            return number.stringValue
        }
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
