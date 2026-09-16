import XCTest
@testable import FastReport

final class MapCatalogTests: XCTestCase {
    func testLoadsInspectionMapFromRepositoryDirectory() throws {
        let result = try MapCatalog.load(from: TestFixtures.mapsDirectory)
        XCTAssertEqual(result.maps.count, 1)
        XCTAssertTrue(result.skipped.isEmpty)
        XCTAssertEqual(result.maps[0].id, "inspection-t24")
    }

    func testSkipsBrokenFilesAndKeepsValidMap() throws {
        try TestFixtures.withTempDirectory { directory in
            try FileManager.default.copyItem(
                at: TestFixtures.inspectionMap,
                to: directory.appendingPathComponent("inspection-t24.json")
            )
            try "{not-json".data(using: .utf8)!.write(to: directory.appendingPathComponent("broken.json"))
            try Data().write(to: directory.appendingPathComponent("empty.json"))

            var invalid = validMapJSON(id: "no-inbox")
            var slots = invalid["slots"] as! [[String: Any]]
            slots.removeAll { ($0["isInbox"] as? Bool) == true }
            invalid["slots"] = slots
            try TestFixtures.writeJSON(invalid, to: directory.appendingPathComponent("no-inbox.json"))

            let result = try MapCatalog.load(from: directory)
            XCTAssertEqual(result.maps.map(\.id), ["inspection-t24"])
            XCTAssertEqual(result.skipped.count, 3)
        }
    }

    func testDuplicateMapIdsAreSkipped() throws {
        try TestFixtures.withTempDirectory { directory in
            try TestFixtures.writeJSON(validMapJSON(id: "same"), to: directory.appendingPathComponent("a.json"))
            try TestFixtures.writeJSON(validMapJSON(id: "same"), to: directory.appendingPathComponent("b.json"))
            let result = try MapCatalog.load(from: directory)
            XCTAssertEqual(result.maps.count, 1)
            XCTAssertEqual(result.skipped.count, 1)
            XCTAssertEqual(result.skipped[0].code, "maps.duplicate_id")
        }
    }

    func testEmptyDirectoryThrows() throws {
        try TestFixtures.withTempDirectory { directory in
            XCTAssertThrowsError(try MapCatalog.load(from: directory)) { error in
                guard case MapCatalogError.noValidMaps = error else {
                    return XCTFail("expected noValidMaps, got \(error)")
                }
            }
        }
    }

    func testMissingDirectoryThrowsUnreadable() {
        let missing = URL(fileURLWithPath: "/tmp/fastreport-does-not-exist-\(UUID().uuidString)")
        XCTAssertThrowsError(try MapCatalog.load(from: missing)) { error in
            guard case MapCatalogError.unreadable = error else {
                return XCTFail("expected unreadable, got \(error)")
            }
        }
    }

    func testUnreadableFileThrows() throws {
        try TestFixtures.withTempDirectory { directory in
            let file = directory.appendingPathComponent("missing.json")
            XCTAssertThrowsError(try MapCatalog.decodeAndValidate(file: file)) { error in
                guard case MapCatalogError.unreadable = error else {
                    return XCTFail("expected unreadable, got \(error)")
                }
            }
        }
    }

    func testBundledInspectionMapLoadsFromAppHost() throws {
        let result = try MapCatalog.loadBundled(from: Bundle.main)
        XCTAssertEqual(result.maps.map(\.id), ["inspection-t24"])
        XCTAssertTrue(result.skipped.isEmpty)
    }
}

@MainActor
final class MapLibraryTests: XCTestCase {
    func testFailedLoadSurfacesAppFailure() throws {
        try TestFixtures.withTempDirectory { directory in
            let library = MapLibrary()
            library.load(from: directory, locale: Locale(identifier: "en"))
            guard case let .failed(failure) = library.state else {
                return XCTFail("expected failed state, got \(library.state)")
            }
            XCTAssertFalse(failure.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertEqual(library.maps, [])
            XCTAssertNotNil(library.loadFailure)
        }
    }

    func testSuccessfulLoadExposesMaps() throws {
        let library = MapLibrary()
        library.load(from: TestFixtures.mapsDirectory, locale: Locale(identifier: "pt"))
        XCTAssertEqual(library.maps.count, 1)
        XCTAssertNil(library.loadFailure)
        XCTAssertTrue(library.warnings.isEmpty)
    }
}
