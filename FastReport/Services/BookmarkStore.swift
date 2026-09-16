import Foundation

protocol BookmarkStoring: Sendable {
    func save(projectURL: URL) throws -> Data
    func resolve(_ data: Data) throws -> (url: URL, isStale: Bool)
}

struct SecurityScopedBookmarkStore: BookmarkStoring {
    func save(projectURL: URL) throws -> Data {
        do {
            return try projectURL.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            return try projectURL.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        }
    }

    func resolve(_ data: Data) throws -> (url: URL, isStale: Bool) {
        if data.isEmpty {
            throw ProjectCreateError.parentInaccessible
        }
        do {
            return try resolve(data, options: [.withSecurityScope, .withoutUI])
        } catch {
            return try resolve(data, options: [.withoutUI])
        }
    }

    private func resolve(_ data: Data, options: URL.BookmarkResolutionOptions) throws -> (url: URL, isStale: Bool) {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: options,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        return (url, isStale)
    }
}
