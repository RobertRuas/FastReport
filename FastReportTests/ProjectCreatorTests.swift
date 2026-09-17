import XCTest
@testable import FastReport

final class ProjectFolderNameTests: XCTestCase {
    func testAcceptsInspectionName() throws {
        XCTAssertEqual(try ProjectFolderName.validate("  Inspeção X  "), "Inspeção X")
    }

    func testRejectsEmptyUnsafeAndLongNames() {
        XCTAssertThrowsError(try ProjectFolderName.validate("   ")) { XCTAssertEqual($0 as? ProjectFolderNameError, .empty) }
        XCTAssertThrowsError(try ProjectFolderName.validate("a/b")) { XCTAssertEqual($0 as? ProjectFolderNameError, .invalid) }
        XCTAssertThrowsError(try ProjectFolderName.validate("a:b")) { XCTAssertEqual($0 as? ProjectFolderNameError, .invalid) }
        XCTAssertThrowsError(try ProjectFolderName.validate("..")) { XCTAssertEqual($0 as? ProjectFolderNameError, .invalid) }
        XCTAssertThrowsError(try ProjectFolderName.validate("nome.")) { XCTAssertEqual($0 as? ProjectFolderNameError, .invalid) }
        let tooLong = String(repeating: "a", count: ProjectFolderName.maxLength + 1)
        XCTAssertThrowsError(try ProjectFolderName.validate(tooLong)) { XCTAssertEqual($0 as? ProjectFolderNameError, .tooLong) }
    }
}

final class ProjectCreatorTests: XCTestCase {
    func testCreatesInspectionStructureAndMetadata() throws {
        try TestFixtures.withTempDirectory { parent in
            let map = try MapCatalog.decodeAndValidate(file: TestFixtures.inspectionMap)
            let createdAt = Date(timeIntervalSince1970: 1_700_000_100)
            var creator = ProjectCreator(bookmarkStore: FakeBookmarkStore())
            creator.now = { createdAt }

            let created = try creator.create(map: map, parent: parent, displayName: "Inspeção X")
            XCTAssertEqual(created.metadata.displayName, "Inspeção X")
            XCTAssertEqual(created.metadata.mapId, "inspection-t24")
            XCTAssertEqual(created.metadata.createdAt, createdAt)
            XCTAssertNotNil(created.bookmarkData)
            XCTAssertNil(created.bookmarkWarning)

            let project = parent.appendingPathComponent("Inspeção X", isDirectory: true)
            XCTAssertEqual(created.url.standardizedFileURL, project.standardizedFileURL)
            XCTAssertTrue(FileManager.default.fileExists(atPath: project.appendingPathComponent(ProjectMetadata.fileName).path))
            XCTAssertEqual(ProjectMetadata.fileName, "fastreport.json")

            for slot in map.slots {
                var isDirectory: ObjCBool = false
                let folder = project.appendingPathComponent(slot.folder, isDirectory: true)
                XCTAssertTrue(
                    FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory),
                    "missing \(slot.folder)"
                )
                XCTAssertTrue(isDirectory.boolValue)
            }

            let data = try Data(contentsOf: project.appendingPathComponent(ProjectMetadata.fileName))
            let metadata = try ProjectMetadata.decode(from: data)
            XCTAssertEqual(metadata, created.metadata)
        }
    }

    func testRejectsExistingProjectAndLeavesOriginalUntouched() throws {
        try TestFixtures.withTempDirectory { parent in
            let map = try MapCatalog.decodeAndValidate(file: TestFixtures.inspectionMap)
            let creator = ProjectCreator(bookmarkStore: FakeBookmarkStore())
            _ = try creator.create(map: map, parent: parent, displayName: "Projeto")
            let marker = parent.appendingPathComponent("Projeto/Inbox/keep.txt")
            try "ok".data(using: .utf8)!.write(to: marker)

            XCTAssertThrowsError(try creator.create(map: map, parent: parent, displayName: "Projeto")) { error in
                XCTAssertEqual(error as? ProjectCreateError, .alreadyExists("Projeto"))
            }
            XCTAssertEqual(try String(contentsOf: marker, encoding: .utf8), "ok")
        }
    }

    func testRejectsMissingParentAndFileAsParent() throws {
        try TestFixtures.withTempDirectory { parent in
            let map = try MapCatalog.decodeAndValidate(file: TestFixtures.inspectionMap)
            let creator = ProjectCreator(bookmarkStore: FakeBookmarkStore())
            let missing = parent.appendingPathComponent("ghost", isDirectory: true)
            XCTAssertThrowsError(try creator.create(map: map, parent: missing, displayName: "P")) { error in
                XCTAssertEqual(error as? ProjectCreateError, .parentMissing)
            }

            let file = parent.appendingPathComponent("file.txt")
            try Data().write(to: file)
            XCTAssertThrowsError(try creator.create(map: map, parent: file, displayName: "P")) { error in
                XCTAssertEqual(error as? ProjectCreateError, .parentNotDirectory)
            }
        }
    }

    func testInvalidNameDoesNotCreateFolder() throws {
        try TestFixtures.withTempDirectory { parent in
            let map = try MapCatalog.decodeAndValidate(file: TestFixtures.inspectionMap)
            let creator = ProjectCreator(bookmarkStore: FakeBookmarkStore())
            XCTAssertThrowsError(try creator.create(map: map, parent: parent, displayName: "a/b"))
            let items = try FileManager.default.contentsOfDirectory(at: parent, includingPropertiesForKeys: nil)
            XCTAssertTrue(items.isEmpty)
        }
    }

    func testBookmarkFailureStillCreatesProjectWithWarning() throws {
        try TestFixtures.withTempDirectory { parent in
            let map = try MapCatalog.decodeAndValidate(file: TestFixtures.inspectionMap)
            var store = FakeBookmarkStore()
            store.saveError = FakeError.boom
            let creator = ProjectCreator(bookmarkStore: store)
            let created = try creator.create(map: map, parent: parent, displayName: "SemAtalho", locale: Locale(identifier: "en"))
            XCTAssertNil(created.bookmarkData)
            XCTAssertEqual(created.bookmarkWarning?.code, "project.bookmark")
            XCTAssertTrue(FileManager.default.fileExists(atPath: created.url.appendingPathComponent("Inbox").path))
        }
    }

    func testInvalidMapDoesNotTouchDisk() throws {
        try TestFixtures.withTempDirectory { parent in
            let map = OrganizationMap(
                id: "bad",
                version: 1,
                name: LocalizedCopy(pt: "A", en: "A"),
                fileNamePattern: "{project}_{slot}_{index}.jpeg",
                inboxFolder: "Inbox",
                slots: []
            )
            let creator = ProjectCreator(bookmarkStore: FakeBookmarkStore())
            XCTAssertThrowsError(try creator.create(map: map, parent: parent, displayName: "X")) { error in
                XCTAssertEqual(error as? ProjectCreateError, .invalidMap)
            }
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(at: parent, includingPropertiesForKeys: nil).count, 0)
        }
    }
}

@MainActor
final class RecentProjectsStoreTests: XCTestCase {
    func testRemembersCreatedProjectAndDropsDuplicates() throws {
        let suite = "dev.robert.FastReport.recents.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            return XCTFail("defaults")
        }
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = RecentProjectsStore(defaults: defaults, bookmarkStore: FakeBookmarkStore())
        let url = URL(fileURLWithPath: "/tmp/Inspecao", isDirectory: true)
        let metadata = try ProjectMetadata(mapId: "inspection-t24", displayName: "Inspeção", createdAt: Date(timeIntervalSince1970: 10)).validated()
        let created = CreatedProject(url: url, metadata: metadata, bookmarkData: Data("b".utf8), bookmarkWarning: nil)

        store.remember(created)
        store.remember(created)
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items[0].displayName, "Inspeção")

        let reloaded = RecentProjectsStore(defaults: defaults, bookmarkStore: FakeBookmarkStore())
        XCTAssertEqual(reloaded.items.count, 1)
        XCTAssertEqual(reloaded.items[0].id, url.standardizedFileURL.path)
    }

    func testSkipsRememberWhenBookmarkIsMissing() throws {
        let suite = "dev.robert.FastReport.recents.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            return XCTFail("defaults")
        }
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = RecentProjectsStore(defaults: defaults, bookmarkStore: FakeBookmarkStore())
        let metadata = try ProjectMetadata(mapId: "inspection-t24", displayName: "X", createdAt: .now).validated()
        let created = CreatedProject(
            url: URL(fileURLWithPath: "/tmp/x"),
            metadata: metadata,
            bookmarkData: nil,
            bookmarkWarning: AppFailure(code: "project.bookmark", message: "warn")
        )
        store.remember(created)
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertEqual(store.lastFailure?.code, "project.bookmark")
    }

    func testRemoveFromListingLeavesDirectory() throws {
        try TestFixtures.withTempDirectory { parent in
            let map = try MapCatalog.decodeAndValidate(file: TestFixtures.inspectionMap)
            let created = try ProjectCreator(bookmarkStore: FakeBookmarkStore()).create(
                map: map,
                parent: parent,
                displayName: "Manter"
            )
            let suite = "dev.robert.FastReport.recents.\(UUID().uuidString)"
            guard let defaults = UserDefaults(suiteName: suite) else {
                return XCTFail("defaults")
            }
            defaults.removePersistentDomain(forName: suite)
            defer { defaults.removePersistentDomain(forName: suite) }

            var bookmarks = FakeBookmarkStore()
            bookmarks.resolvedURL = created.url
            bookmarks.data = created.bookmarkData ?? Data("b".utf8)
            let store = RecentProjectsStore(defaults: defaults, bookmarkStore: bookmarks)
            store.remember(created)
            XCTAssertEqual(store.items.count, 1)
            store.removeFromListing(store.items[0])
            XCTAssertTrue(store.items.isEmpty)
            XCTAssertTrue(FileManager.default.fileExists(atPath: created.url.path))
        }
    }

    func testDeleteProjectDirectoryRemovesFolder() throws {
        try TestFixtures.withTempDirectory { parent in
            let map = try MapCatalog.decodeAndValidate(file: TestFixtures.inspectionMap)
            let created = try ProjectCreator(bookmarkStore: FakeBookmarkStore()).create(
                map: map,
                parent: parent,
                displayName: "Apagar"
            )
            let suite = "dev.robert.FastReport.recents.\(UUID().uuidString)"
            guard let defaults = UserDefaults(suiteName: suite) else {
                return XCTFail("defaults")
            }
            defaults.removePersistentDomain(forName: suite)
            defer { defaults.removePersistentDomain(forName: suite) }

            var bookmarks = FakeBookmarkStore()
            bookmarks.resolvedURL = created.url
            bookmarks.data = created.bookmarkData ?? Data("b".utf8)
            let store = RecentProjectsStore(defaults: defaults, bookmarkStore: bookmarks)
            store.remember(created)
            store.deleteProjectDirectory(store.items[0], locale: Locale(identifier: "pt"))
            XCTAssertNil(store.lastFailure)
            XCTAssertTrue(store.items.isEmpty)
            XCTAssertFalse(FileManager.default.fileExists(atPath: created.url.path))
        }
    }

    func testDeleteRefusesFolderWithoutIndex() throws {
        try TestFixtures.withTempDirectory { directory in
            let suite = "dev.robert.FastReport.recents.\(UUID().uuidString)"
            guard let defaults = UserDefaults(suiteName: suite) else {
                return XCTFail("defaults")
            }
            defaults.removePersistentDomain(forName: suite)
            defer { defaults.removePersistentDomain(forName: suite) }

            var bookmarks = FakeBookmarkStore()
            bookmarks.resolvedURL = directory
            bookmarks.data = Data("b".utf8)
            let store = RecentProjectsStore(defaults: defaults, bookmarkStore: bookmarks)
            let metadata = try ProjectMetadata(mapId: "inspection-t24", displayName: "X", createdAt: .now).validated()
            store.remember(CreatedProject(url: directory, metadata: metadata, bookmarkData: Data("b".utf8), bookmarkWarning: nil))
            store.deleteProjectDirectory(store.items[0], locale: Locale(identifier: "pt"))
            XCTAssertEqual(store.lastFailure?.code, "project.delete.not_project")
            XCTAssertEqual(store.items.count, 1)
            XCTAssertTrue(FileManager.default.fileExists(atPath: directory.path))
        }
    }
}

@MainActor
final class ProjectWizardModelTests: XCTestCase {
    func testCreateRequiresLocationAndValidName() throws {
        let map = try MapCatalog.decodeAndValidate(file: TestFixtures.inspectionMap)
        let model = ProjectWizardModel(maps: [map])
        XCTAssertEqual(model.selectedMapID, map.id)
        model.goToDetails(locale: Locale(identifier: "pt"))
        XCTAssertEqual(model.step, .details)

        try TestFixtures.withTempDirectory { parent in
            let suite = "wizard-\(UUID().uuidString)"
            guard let defaults = UserDefaults(suiteName: suite) else {
                return XCTFail("defaults")
            }
            defaults.removePersistentDomain(forName: suite)
            defer { defaults.removePersistentDomain(forName: suite) }
            let recents = RecentProjectsStore(
                defaults: defaults,
                bookmarkStore: FakeBookmarkStore()
            )
            model.createProject(creator: ProjectCreator(bookmarkStore: FakeBookmarkStore()), recents: recents, locale: Locale(identifier: "pt"))
            XCTAssertEqual(model.locationError?.code, ProjectCreateError.parentMissing.code)

            model.parentURL = parent
            model.projectName = "a/b"
            model.createProject(creator: ProjectCreator(bookmarkStore: FakeBookmarkStore()), recents: recents, locale: Locale(identifier: "pt"))
            XCTAssertEqual(model.nameError?.code, ProjectFolderNameError.invalid.code)

            model.projectName = "Dia 1"
            model.createProject(creator: ProjectCreator(bookmarkStore: FakeBookmarkStore()), recents: recents, locale: Locale(identifier: "pt"))
            XCTAssertEqual(model.step, .success)
            XCTAssertEqual(model.created?.metadata.displayName, "Dia 1")
            XCTAssertTrue(FileManager.default.fileExists(atPath: parent.appendingPathComponent("Dia 1/T24").path))
        }
    }

    func testEmptyMapsSurfacesFailure() {
        let model = ProjectWizardModel(maps: [])
        XCTAssertEqual(model.failure?.code, MapCatalogError.noValidMaps([]).code)
        XCTAssertFalse(model.canContinueFromMap)
    }
}
