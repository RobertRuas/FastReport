import Foundation
import XCTest
@testable import FastReport

private final class TestBundleToken {}

enum TestFixtures {
    static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    static var bundle: Bundle { Bundle(for: TestBundleToken.self) }

    static var mapsDirectory: URL {
        if let bundled = bundle.url(forResource: "Maps", withExtension: nil) {
            return bundled
        }
        if let file = bundle.url(forResource: "inspection-t24", withExtension: "json") {
            return file.deletingLastPathComponent()
        }
        return repositoryRoot.appendingPathComponent("FastReport/Resources/Maps", isDirectory: true)
    }

    static var inspectionMap: URL {
        if let bundled = bundle.url(forResource: "inspection-t24", withExtension: "json", subdirectory: "Maps") {
            return bundled
        }
        if let bundled = bundle.url(forResource: "inspection-t24", withExtension: "json") {
            return bundled
        }
        return mapsDirectory.appendingPathComponent("inspection-t24.json")
    }

    static var stringCatalog: URL {
        if let bundled = bundle.url(forResource: "Localizable", withExtension: "xcstrings") {
            return bundled
        }
        return repositoryRoot.appendingPathComponent("FastReport/Resources/Localizable.xcstrings")
    }

    static func withTempDirectory(_ body: (URL) throws -> Void) throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("FastReportTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: url) }
        try body(url)
    }

    static func writeJSON(_ object: Any, to url: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted])
        try data.write(to: url, options: [.atomic])
    }
}

func validMapJSON(
    id: String = "test-map",
    inboxFolder: String = "Inbox",
    extraSlots: [[String: Any]] = []
) -> [String: Any] {
    var slots: [[String: Any]] = [
        [
            "id": "inbox",
            "folder": "Inbox",
            "hotkeys": [],
            "unlimited": true,
            "isInbox": true,
            "isTrash": false
        ],
        [
            "id": "general",
            "folder": "General",
            "hotkeys": ["0"],
            "unlimited": true,
            "isInbox": false,
            "isTrash": false
        ],
        [
            "id": "trash",
            "folder": "Trash",
            "hotkeys": ["cmd+backspace"],
            "unlimited": true,
            "isInbox": false,
            "isTrash": true
        ]
    ]
    slots.append(contentsOf: extraSlots)
    return [
        "id": id,
        "version": 1,
        "name": ["pt": "Teste", "en": "Test"],
        "fileNamePattern": "{project}_{slot}_{index}.jpeg",
        "inboxFolder": inboxFolder,
        "slots": slots
    ]
}
