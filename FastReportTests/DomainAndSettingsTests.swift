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

final class LiveReorderLayoutTests: XCTestCase {
    func testMovesForwardIntoTheNextIndexInsteadOfNoOp() {
        XCTAssertEqual(LiveReorderLayout.movingItem(in: [0, 1, 2, 3], from: 0, to: 1), [1, 0, 2, 3])
        XCTAssertEqual(LiveReorderLayout.movingItem(in: [0, 1, 2, 3], from: 0, to: 3), [1, 2, 3, 0])
        XCTAssertEqual(LiveReorderLayout.movingItem(in: [0, 1, 2, 3], from: 3, to: 1), [0, 3, 1, 2])
        XCTAssertEqual(LiveReorderLayout.movingItem(in: [0, 1, 2], from: 1, to: 1), [0, 1, 2])
    }

    func testTargetIndexCrossesOneCellAtHalfWidth() {
        XCTAssertEqual(
            LiveReorderLayout.targetIndex(from: 0, translationX: 40, cellWidth: 80, count: 5),
            1
        )
        XCTAssertEqual(
            LiveReorderLayout.targetIndex(from: 2, translationX: -40, cellWidth: 80, count: 5),
            1
        )
        XCTAssertEqual(
            LiveReorderLayout.targetIndex(from: 0, translationX: 400, cellWidth: 80, count: 3),
            2
        )
        XCTAssertEqual(
            LiveReorderLayout.targetIndex(from: 1, translationX: 10, cellWidth: 80, count: 3),
            1
        )
    }

    func testNeighborsSlideAsideWithoutReorderingTheSourceArray() {
        XCTAssertEqual(
            LiveReorderLayout.neighborOffset(index: 1, dragIndex: 0, targetIndex: 2, cellWidth: 80),
            -80
        )
        XCTAssertEqual(
            LiveReorderLayout.neighborOffset(index: 0, dragIndex: 2, targetIndex: 0, cellWidth: 80),
            80
        )
        XCTAssertEqual(
            LiveReorderLayout.neighborOffset(index: 3, dragIndex: 0, targetIndex: 2, cellWidth: 80),
            0
        )
    }
}

final class ReviewDisplaySlotsTests: XCTestCase {
    func testKeepsGeneralAndTrashTogetherAheadOfNumberedSlots() throws {
        let map = try MapCatalog.decodeAndValidate(file: TestFixtures.inspectionMap)
        let general = try XCTUnwrap(map.slot(folder: "General"))
        let trash = try XCTUnwrap(map.trash)
        let t1 = try XCTUnwrap(map.slot(folder: "T1"))
        let t2 = try XCTUnwrap(map.slot(folder: "T2"))
        let parts = ReviewDisplaySlots.partitions(
            map: map,
            occupiedIds: [general.id, trash.id, t1.id, t2.id]
        )
        XCTAssertEqual(parts.special.map(\.folder), ["General", "Trash"])
        XCTAssertEqual(parts.regular.map(\.folder), ["T1", "T2"])
        XCTAssertEqual(
            ReviewDisplaySlots.ordered(map: map, occupiedIds: [general.id, trash.id, t1.id]).map(\.folder),
            ["General", "Trash", "T1"]
        )
    }

    func testDeliveryOmitsTrashAndInbox() throws {
        let map = try MapCatalog.decodeAndValidate(file: TestFixtures.inspectionMap)
        let general = try XCTUnwrap(map.slot(folder: "General"))
        let trash = try XCTUnwrap(map.trash)
        let inbox = try XCTUnwrap(map.inbox)
        let t1 = try XCTUnwrap(map.slot(folder: "T1"))
        let parts = ReviewDisplaySlots.deliveryPartitions(
            map: map,
            occupiedIds: [general.id, trash.id, inbox.id, t1.id]
        )
        XCTAssertEqual(parts.special.map(\.folder), ["General"])
        XCTAssertEqual(parts.regular.map(\.folder), ["T1"])
    }
}

final class DeliveryLedgerTests: XCTestCase {
    func testRoundTripAndKeepsPlacementAfterRename() throws {
        try TestFixtures.withTempDirectory { dir in
            let folder = dir.appendingPathComponent("T1", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let original = folder.appendingPathComponent("Inspecao_T1_1.jpeg")
            try TestImageFactory.writePNG(width: 32, height: 32, to: original)

            let photo = DiskPhoto(url: original, slotId: "t1", fileName: original.lastPathComponent)
            let marked = DeliveryLedger().placing(photo, projectURL: dir)
            try marked.save(in: dir)
            XCTAssertTrue(FileManager.default.fileExists(atPath: DeliveryLedger.fileURL(in: dir).path))

            let renamed = folder.appendingPathComponent("Inspecao_T1_2.jpeg")
            try FileManager.default.moveItem(at: original, to: renamed)
            let loaded = DeliveryLedger.load(from: dir)
            let moved = DiskPhoto(url: renamed, slotId: "t1", fileName: renamed.lastPathComponent)
            XCTAssertTrue(loaded.contains(moved, projectURL: dir))

            let refreshed = loaded.refreshing(to: [moved], projectURL: dir)
            XCTAssertTrue(refreshed.contains(moved, projectURL: dir))
            XCTAssertEqual(refreshed.placedPaths, ["T1/Inspecao_T1_2.jpeg"])
        }
    }

    func testToggleRemovesPlacement() throws {
        try TestFixtures.withTempDirectory { dir in
            let url = dir.appendingPathComponent("General/a.png")
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try TestImageFactory.writePNG(width: 16, height: 16, to: url)
            let photo = DiskPhoto(url: url, slotId: "general", fileName: "a.png")
            let marked = DeliveryLedger().placing(photo, projectURL: dir)
            XCTAssertTrue(marked.contains(photo, projectURL: dir))
            XCTAssertFalse(marked.toggling(photo, projectURL: dir).contains(photo, projectURL: dir))
        }
    }
}

@MainActor
final class ThumbnailSizeStoreTests: XCTestCase {
    func testAutomaticSizeGrowsWithWidthAndNeverDropsBelowMinimum() {
        XCTAssertEqual(ThumbnailSizeStore.automaticSize(containerWidth: 696), 80)
        XCTAssertEqual(ThumbnailSizeStore.automaticSize(containerWidth: 200), ThumbnailSizeStore.minSize)
        XCTAssertEqual(ThumbnailSizeStore.automaticSize(containerWidth: 2_000), ThumbnailSizeStore.maxSize)
        XCTAssertGreaterThan(
            ThumbnailSizeStore.automaticSize(containerWidth: 900),
            ThumbnailSizeStore.automaticSize(containerWidth: 720)
        )
        XCTAssertEqual(
            ThumbnailSizeStore.automaticSize(containerWidth: 696, photoCount: 20),
            ThumbnailSizeStore.minSize
        )
    }

    func testMinusLeavesAutomaticAndPersistsManualStep() throws {
        let suite = "dev.robert.FastReport.thumbs.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            return XCTFail("could not create defaults suite")
        }
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = ThumbnailSizeStore(defaults: defaults)
        XCTAssertEqual(store.mode, .automatic)
        store.makeSmaller(currentSize: 80)
        XCTAssertEqual(store.mode, .manual)
        XCTAssertEqual(store.size(containerWidth: 900), 64)
        XCTAssertEqual(defaults.string(forKey: ThumbnailSizeStore.modeKey), "manual")

        store.useAutomatic()
        XCTAssertEqual(store.mode, .automatic)
    }
}

final class UpdateProgressMathTests: XCTestCase {
    func testReachesOneHundredWhenWaitingToRelaunch() {
        XCTAssertEqual(
            UpdateProgressMath.fraction(phase: .readyToInstall, received: 0, expected: 0, extraction: 1),
            1
        )
        XCTAssertEqual(
            UpdateProgressMath.fraction(phase: .installing, received: 1, expected: 1, extraction: 1),
            1
        )
        XCTAssertEqual(
            UpdateProgressMath.fraction(phase: .downloading, received: 50, expected: 100, extraction: 0),
            0.45,
            accuracy: 0.0001
        )
    }
}

final class HoverHintLayoutTests: XCTestCase {
    func testKeepsThePanelInsideTheVisibleFrameNearTheTrailingEdge() {
        let frame = HoverHintLayout.panelFrame(
            anchor: CGRect(x: 760, y: 200, width: 30, height: 30),
            bubble: CGSize(width: 240, height: 72),
            visible: CGRect(x: 0, y: 0, width: 800, height: 600),
            preferred: .below
        )
        XCTAssertGreaterThanOrEqual(frame.minX, 8)
        XCTAssertLessThanOrEqual(frame.maxX, 792)
        XCTAssertEqual(frame.width, 240)
    }

    func testFlipsAboveWhenTheButtonIsNearTheBottom() {
        let frame = HoverHintLayout.panelFrame(
            anchor: CGRect(x: 40, y: 12, width: 30, height: 30),
            bubble: CGSize(width: 200, height: 80),
            visible: CGRect(x: 0, y: 0, width: 800, height: 600),
            preferred: .below
        )
        XCTAssertGreaterThanOrEqual(frame.minY, 8)
        XCTAssertGreaterThan(frame.minY, 42)
    }
}
