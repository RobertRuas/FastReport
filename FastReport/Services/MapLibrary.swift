import Foundation
import Observation

@MainActor
@Observable
final class MapLibrary {
    enum State: Equatable {
        case idle
        case loaded(maps: [OrganizationMap], warnings: [AppFailure])
        case failed(AppFailure)
    }

    private(set) var state: State = .idle

    var maps: [OrganizationMap] {
        if case let .loaded(maps, _) = state { return maps }
        return []
    }

    var loadFailure: AppFailure? {
        if case let .failed(failure) = state { return failure }
        return nil
    }

    var warnings: [AppFailure] {
        if case let .loaded(_, warnings) = state { return warnings }
        return []
    }

    func loadBundled(bundle: Bundle = .main, locale: Locale) {
        do {
            let result = try MapCatalog.loadBundled(from: bundle)
            state = .loaded(maps: result.maps, warnings: result.skipped)
        } catch {
            state = .failed(AppFailure(error, locale: locale))
        }
    }

    func load(from directory: URL, locale: Locale) {
        do {
            let result = try MapCatalog.load(from: directory)
            state = .loaded(maps: result.maps, warnings: result.skipped)
        } catch {
            state = .failed(AppFailure(error, locale: locale))
        }
    }
}
