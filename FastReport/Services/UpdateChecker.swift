import Foundation

struct GitHubRelease: Equatable, Sendable {
    var tagName: String
    var htmlURL: URL?
    var name: String
    var publishedAt: Date?
    var body: String

    var normalizedTag: String {
        tagName.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
    }
}

enum UpdateCheckResult: Equatable, Sendable {
    case notConfigured
    case upToDate(current: String)
    case available(release: GitHubRelease)
}

enum UpdateChecker {
    static func parseRelease(data: Data) throws -> GitHubRelease {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let json = object as? [String: Any],
              let tag = (json["tag_name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !tag.isEmpty
        else {
            throw AppFailure(code: "updates.parse", message: String(localized: "error.updates.parse", locale: Locale(identifier: "pt")))
        }
        let html = json["html_url"] as? String
        let name = (json["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return GitHubRelease(
            tagName: tag,
            htmlURL: html.flatMap(URL.init(string:)),
            name: (name?.isEmpty == false ? name! : tag),
            publishedAt: Self.parseDate(json["published_at"] as? String),
            body: (json["body"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        )
    }

    static func compare(current: String, latest: GitHubRelease) -> UpdateCheckResult {
        let currentNorm = current.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        if latest.normalizedTag.isEmpty {
            return .upToDate(current: currentNorm)
        }
        if latest.normalizedTag == currentNorm {
            return .upToDate(current: currentNorm)
        }
        if isVersion(latest.normalizedTag, newerThan: currentNorm) {
            return .available(release: latest)
        }
        return .upToDate(current: currentNorm)
    }

    static func isVersion(_ lhs: String, newerThan rhs: String) -> Bool {
        let left = lhs.split(separator: ".").compactMap { Int($0) }
        let right = rhs.split(separator: ".").compactMap { Int($0) }
        let count = max(left.count, right.count)
        for index in 0..<count {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l != r { return l > r }
        }
        return false
    }

    static func configuredURL(from info: [String: Any]) -> URL? {
        let raw = (info["SUFeedURL"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? (info["FRUpdatesURL"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ""
        guard !raw.isEmpty, let url = URL(string: raw), let scheme = url.scheme, scheme == "https" else {
            return nil
        }
        return url
    }

    private static func parseDate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: raw) { return date }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: raw)
    }
}
