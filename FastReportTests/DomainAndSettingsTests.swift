import XCTest
@testable import FastReport

final class FileNameFormatterTests: XCTestCase {
    func testBuildsInspectionFileName() throws {
        let name = try FileNameFormatter.fileName(
            pattern: "{project}_{slot}_{index}.jpeg",
            project: "Inspecao1",
            slot: "T10",
            index: 1
        )
        XCTAssertEqual(name, "Inspecao1_T10_1.jpeg")
    }

    func testRejectsInvalidIndexAndEmptyParts() {
        XCTAssertThrowsError(
            try FileNameFormatter.fileName(pattern: "{project}_{slot}_{index}.jpeg", project: "", slot: "T1", index: 1)
        ) { XCTAssertEqual($0 as? FileNameError, .emptyProject) }

        XCTAssertThrowsError(
            try FileNameFormatter.fileName(pattern: "{project}_{slot}_{index}.jpeg", project: "P", slot: " ", index: 1)
        ) { XCTAssertEqual($0 as? FileNameError, .emptySlot) }

        XCTAssertThrowsError(
            try FileNameFormatter.fileName(pattern: "{project}_{slot}_{index}.jpeg", project: "P", slot: "T1", index: 0)
        ) { XCTAssertEqual($0 as? FileNameError, .invalidIndex(0)) }

        XCTAssertThrowsError(
            try FileNameFormatter.fileName(pattern: "{project}_{index}.jpeg", project: "P", slot: "T1", index: 1)
        ) { XCTAssertEqual($0 as? FileNameError, .missingToken("{slot}")) }
    }

    func testRejectsPathSeparatorsInResult() {
        XCTAssertThrowsError(
            try FileNameFormatter.fileName(
                pattern: "{project}_{slot}_{index}.jpeg",
                project: "a/b",
                slot: "T1",
                index: 1
            )
        ) { XCTAssertEqual($0 as? FileNameError, .unsafeCharacters) }
    }
}

final class ProjectSlugTests: XCTestCase {
    func testNormalizesPortugueseInspectionName() throws {
        XCTAssertEqual(try ProjectSlug.make(from: "Inspeção 1"), "Inspecao_1")
        XCTAssertEqual(try ProjectSlug.make(from: "  Inspecao1  "), "Inspecao1")
    }

    func testRejectsEmptyAndUnusableNames() {
        XCTAssertThrowsError(try ProjectSlug.make(from: "   ")) { XCTAssertEqual($0 as? ProjectSlugError, .empty) }
        XCTAssertThrowsError(try ProjectSlug.make(from: "...")) { XCTAssertEqual($0 as? ProjectSlugError, .invalid) }
        XCTAssertThrowsError(try ProjectSlug.make(from: "***")) { XCTAssertEqual($0 as? ProjectSlugError, .invalid) }
    }
}

final class ProjectMetadataTests: XCTestCase {
    func testRoundTripISO8601() throws {
        let original = try ProjectMetadata(
            mapId: "inspection-t24",
            displayName: "Inspeção X",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        ).validated()
        let data = try ProjectMetadata.makeEncoder().encode(original)
        let decoded = try ProjectMetadata.decode(from: data)
        XCTAssertEqual(decoded.mapId, original.mapId)
        XCTAssertEqual(decoded.displayName, original.displayName)
        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.createdAt.timeIntervalSince1970, original.createdAt.timeIntervalSince1970, accuracy: 1)
    }

    func testRejectsUnsupportedAndEmptyValues() throws {
        XCTAssertThrowsError(try ProjectMetadata(schemaVersion: 0, mapId: "a", displayName: "b", createdAt: .now).validated())
        XCTAssertThrowsError(try ProjectMetadata(schemaVersion: 99, mapId: "a", displayName: "b", createdAt: .now).validated())
        XCTAssertThrowsError(try ProjectMetadata(mapId: " ", displayName: "b", createdAt: .now).validated())
        XCTAssertThrowsError(try ProjectMetadata(mapId: "a", displayName: " ", createdAt: .now).validated())
        XCTAssertThrowsError(try ProjectMetadata.decode(from: Data("{".utf8)))
    }
}

final class AppLanguageStoreTests: XCTestCase {
    func testResolvesUnknownValuesToPortuguese() {
        XCTAssertEqual(AppLanguage.resolved(stored: nil), .portuguese)
        XCTAssertEqual(AppLanguage.resolved(stored: " "), .portuguese)
        XCTAssertEqual(AppLanguage.resolved(stored: "fr"), .portuguese)
        XCTAssertEqual(AppLanguage.resolved(stored: "PT-BR"), .portuguese)
        XCTAssertEqual(AppLanguage.resolved(stored: "en-US"), .english)
    }

    @MainActor
    func testPersistsSelectionInIsolatedDefaults() throws {
        let suite = "dev.robert.FastReport.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            return XCTFail("could not create defaults suite")
        }
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = AppLanguageStore(defaults: defaults)
        XCTAssertEqual(store.language, .portuguese)
        XCTAssertEqual(defaults.string(forKey: AppLanguageStore.storageKey), "pt")

        store.setLanguage(.english)
        XCTAssertEqual(store.language, .english)
        XCTAssertEqual(defaults.string(forKey: AppLanguageStore.storageKey), "en")

        let reloaded = AppLanguageStore(defaults: defaults)
        XCTAssertEqual(reloaded.language, .english)
        XCTAssertEqual(reloaded.locale.identifier, "en")
    }
}

final class AppFailureTests: XCTestCase {
    func testNeverExposesEmptyMessage() {
        let failure = AppFailure(code: " ", message: " ", debugDescription: nil)
        XCTAssertEqual(failure.code, "unknown")
        XCTAssertFalse(failure.message.isEmpty)
        XCTAssertEqual(failure.debugDescription, failure.message)
    }

    func testWrapsCatalogErrors() {
        let wrapped = AppFailure(MapCatalogError.mapsDirectoryMissing, locale: Locale(identifier: "en"))
        XCTAssertEqual(wrapped.code, "maps.missing")
        XCTAssertFalse(wrapped.message.isEmpty)
    }
}

final class AppVersionTests: XCTestCase {
    func testFallsBackWhenInfoIsMissing() {
        XCTAssertEqual(AppVersion.marketing(info: [:]), "0.0.0")
        XCTAssertEqual(AppVersion.build(info: [:]), "0")
        XCTAssertEqual(AppVersion.display(info: [:]), "0.0.0 (0)")
    }

    func testReadsValuesAndTrims() {
        XCTAssertEqual(
            AppVersion.display(info: [
                "CFBundleShortVersionString": " 0.1.0 ",
                "CFBundleVersion": " 12 "
            ]),
            "0.1.0 (12)"
        )
        XCTAssertEqual(AppVersion.build(info: ["CFBundleVersion": 7]), "7")
    }
}

final class LocalizedCopyTests: XCTestCase {
    func testFallsBackWhenOneLanguageIsBlank() {
        let copy = LocalizedCopy(pt: "Olá", en: "  ")
        XCTAssertEqual(copy.resolved(language: .english), "Olá")
        XCTAssertEqual(LocalizedCopy(pt: " ", en: "Hi").resolved(language: .portuguese), "Hi")
        XCTAssertEqual(copy.validated(), nil)
        XCTAssertEqual(LocalizedCopy(pt: " ", en: "").validated(), .missingBoth)
    }
}

final class PhotoItemTests: XCTestCase {
    func testIdentityIsStableForGivenId() {
        let id = UUID()
        let item = PhotoItem(id: id, fileName: "a.jpeg", slotId: "inbox")
        XCTAssertEqual(item.id, id)
        XCTAssertEqual(item.slotId, "inbox")
    }
}

final class StringCatalogTests: XCTestCase {
    func testEveryRequiredKeyHasPortugueseAndEnglish() throws {
        let data = try Data(contentsOf: TestFixtures.stringCatalog)
        let object = try JSONSerialization.jsonObject(with: data)
        guard
            let root = object as? [String: Any],
            let strings = root["strings"] as? [String: Any],
            root["sourceLanguage"] as? String == "pt"
        else {
            return XCTFail("invalid string catalog")
        }

        var missing: [String] = []
        for key in StringCatalog.requiredKeys {
            guard let entry = strings[key] as? [String: Any],
                  let localizations = entry["localizations"] as? [String: Any]
            else {
                missing.append(key)
                continue
            }
            for language in ["pt", "en"] {
                let value = ((localizations[language] as? [String: Any])?["stringUnit"] as? [String: Any])?["value"] as? String
                if value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                    missing.append("\(key):\(language)")
                }
            }
        }
        XCTAssertTrue(missing.isEmpty, "missing translations: \(missing.joined(separator: ", "))")
        XCTAssertEqual(Set(strings.keys).subtracting(StringCatalog.requiredKeys).count, 0, "catalog has extra keys not listed in StringCatalog.requiredKeys")
    }
}
