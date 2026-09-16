import Foundation
@testable import FastReport

struct FakeBookmarkStore: BookmarkStoring {
    var saveError: Error?
    var resolveError: Error?
    var resolvedURL: URL?
    var isStale = false
    var data = Data("bookmark".utf8)

    func save(projectURL: URL) throws -> Data {
        if let saveError { throw saveError }
        return data
    }

    func resolve(_ data: Data) throws -> (url: URL, isStale: Bool) {
        if let resolveError { throw resolveError }
        return (resolvedURL ?? URL(fileURLWithPath: "/tmp/fastreport-fake"), isStale)
    }
}

enum FakeError: Error {
    case boom
}
