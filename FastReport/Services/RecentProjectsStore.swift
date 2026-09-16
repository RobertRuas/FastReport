import Foundation
import Observation

struct RecentProject: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var displayName: String
    var path: String
    var bookmarkData: Data
    var createdAt: Date

    var url: URL {
        URL(fileURLWithPath: path, isDirectory: true)
    }
}

@MainActor
@Observable
final class RecentProjectsStore {
    static let storageKey = "fastreport.recentProjects"
    static let limit = 8

    private let defaults: UserDefaults
    private let bookmarkStore: any BookmarkStoring
    private(set) var items: [RecentProject]
    private(set) var lastFailure: AppFailure?

    init(defaults: UserDefaults = .standard, bookmarkStore: any BookmarkStoring = SecurityScopedBookmarkStore()) {
        self.defaults = defaults
        self.bookmarkStore = bookmarkStore
        self.items = Self.load(from: defaults)
    }

    func remember(_ created: CreatedProject) {
        lastFailure = created.bookmarkWarning
        guard let bookmarkData = created.bookmarkData, !bookmarkData.isEmpty else { return }
        let record = RecentProject(
            id: created.url.standardizedFileURL.path,
            displayName: created.metadata.displayName,
            path: created.url.standardizedFileURL.path,
            bookmarkData: bookmarkData,
            createdAt: created.metadata.createdAt
        )
        items.removeAll { $0.id == record.id || $0.path == record.path }
        items.insert(record, at: 0)
        if items.count > Self.limit {
            items = Array(items.prefix(Self.limit))
        }
        persist()
    }

    func resolvedURL(for project: RecentProject, locale: Locale) -> URL? {
        lastFailure = nil
        do {
            let resolved = try bookmarkStore.resolve(project.bookmarkData)
            if resolved.isStale, let refreshed = try? bookmarkStore.save(projectURL: resolved.url) {
                updateBookmark(id: project.id, data: refreshed, path: resolved.url.standardizedFileURL.path)
            }
            return resolved.url
        } catch {
            lastFailure = AppFailure(
                code: "project.bookmark.resolve",
                message: String(localized: "error.project.bookmark.resolve", locale: locale),
                debugDescription: error.localizedDescription
            )
            return nil
        }
    }

    func remove(id: String) {
        items.removeAll { $0.id == id }
        persist()
    }

    private func updateBookmark(id: String, data: Data, path: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].bookmarkData = data
        items[index].path = path
        persist()
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(items)
            defaults.set(data, forKey: Self.storageKey)
        } catch {
            lastFailure = AppFailure(
                code: "project.recents.persist",
                message: String(localized: "error.generic", locale: Locale(identifier: "pt")),
                debugDescription: error.localizedDescription
            )
        }
    }

    private static func load(from defaults: UserDefaults) -> [RecentProject] {
        guard let data = defaults.data(forKey: storageKey) else { return [] }
        do {
            let decoded = try JSONDecoder().decode([RecentProject].self, from: data)
            return Array(decoded.prefix(limit))
        } catch {
            defaults.removeObject(forKey: storageKey)
            return []
        }
    }
}
