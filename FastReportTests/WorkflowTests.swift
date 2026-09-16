import XCTest
@testable import FastReport

final class ClassificationBufferTests: XCTestCase {
    func testDigitsResolveT10NotT1() throws {
        let map = try MapCatalog.decodeAndValidate(file: TestFixtures.inspectionMap)
        var buffer = ClassificationBuffer()
        buffer.append("1")
        XCTAssertEqual(buffer.slot(in: map)?.folder, "T1")
        buffer.append("0")
        XCTAssertEqual(buffer.preview, "T10")
        XCTAssertEqual(buffer.slot(in: map)?.folder, "T10")
    }

    func testZeroAndGResolveGeneralAndUnknownClearsMeaningfully() throws {
        let map = try MapCatalog.decodeAndValidate(file: TestFixtures.inspectionMap)
        var buffer = ClassificationBuffer()
        buffer.append("0")
        XCTAssertEqual(buffer.slot(in: map)?.folder, "General")
        buffer.clear()
        buffer.append("G")
        XCTAssertEqual(buffer.slot(in: map)?.folder, "General")
        buffer.clear()
        buffer.append("9")
        buffer.append("9")
        XCTAssertNil(buffer.slot(in: map))
        buffer.clear()
        XCTAssertEqual(buffer.preview, "")
    }
}

final class ImagePipelineTests: XCTestCase {
    func testConvertsPNGToJPEGCappedAt1024() throws {
        try TestFixtures.withTempDirectory { directory in
            let source = directory.appendingPathComponent("wide.png")
            let destination = directory.appendingPathComponent("wide.jpeg")
            try TestImageFactory.writePNG(width: 2048, height: 512, to: source)
            try ImagePipeline.convertToJPEG(source: source, destination: destination)
            XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
            let size = try XCTUnwrap(ImagePipeline.pixelSize(of: destination))
            XCTAssertEqual(size.0, 1024)
            XCTAssertEqual(size.1, 256)
        }
    }

    func testRejectsNonImageAndRotatesJPEG() throws {
        try TestFixtures.withTempDirectory { directory in
            let text = directory.appendingPathComponent("notes.txt")
            try "hello".data(using: .utf8)!.write(to: text)
            XCTAssertThrowsError(try ImagePipeline.convertToJPEG(source: text, destination: directory.appendingPathComponent("x.jpeg")))

            let source = directory.appendingPathComponent("square.png")
            let jpeg = directory.appendingPathComponent("square.jpeg")
            try TestImageFactory.writePNG(width: 400, height: 200, to: source)
            try ImagePipeline.convertToJPEG(source: source, destination: jpeg)
            try ImagePipeline.rotateClockwise(at: jpeg)
            let size = try XCTUnwrap(ImagePipeline.pixelSize(of: jpeg))
            XCTAssertEqual(size.0, 200)
            XCTAssertEqual(size.1, 400)
        }
    }
}

final class UpdateCheckerTests: XCTestCase {
    func testParsesGitHubReleaseAndComparesVersions() throws {
        let json = """
        {"tag_name":"v1.2.0","html_url":"https://example.com/r","name":"FastReport 1.2.0","published_at":"2026-09-16T12:00:00Z","body":"notes"}
        """.data(using: .utf8)!
        let release = try UpdateChecker.parseRelease(data: json)
        XCTAssertEqual(release.normalizedTag, "1.2.0")
        XCTAssertEqual(release.body, "notes")
        XCTAssertNotNil(release.publishedAt)
        XCTAssertEqual(UpdateChecker.compare(current: "0.1.0", latest: release), .available(release: release))
        XCTAssertEqual(UpdateChecker.compare(current: "1.2.0", latest: release), .upToDate(current: "1.2.0"))
        XCTAssertFalse(UpdateChecker.isVersion("1.0.0", newerThan: "1.2.0"))
        XCTAssertNil(UpdateChecker.configuredURL(from: [:]))
        XCTAssertNil(UpdateChecker.configuredURL(from: ["FRUpdatesURL": "http://insecure.example"]))
        XCTAssertNotNil(UpdateChecker.configuredURL(from: ["FRUpdatesURL": "https://api.github.com/repos/a/b/releases/latest"]))
        XCTAssertNotNil(UpdateChecker.configuredURL(from: ["SUFeedURL": "https://github.com/RobertRuas/FastReport/releases/latest/download/appcast.xml"]))
    }

    func testTreatsSparkleRelaunchErrorsAsInstalled() {
        let relaunch = NSError(domain: "SUSparkleErrorDomain", code: 4000)
        XCTAssertTrue(SparkleInstallError.happenedAfterInstallStarted(.installing))
        XCTAssertTrue(SparkleInstallError.happenedAfterInstallStarted(.extracting))
        XCTAssertFalse(SparkleInstallError.happenedAfterInstallStarted(.checking))
        XCTAssertFalse(SparkleInstallError.isCancellation(relaunch))
        XCTAssertTrue(SparkleInstallError.isCancellation(NSError(domain: "SUSparkleErrorDomain", code: 4002)))
        XCTAssertFalse(SparkleInstallError.isCancellation(NSError(domain: "NSURLErrorDomain", code: -1009)))
    }
}

final class FileOrganizerFlowTests: XCTestCase {
    func testImportClassifyUndoAndReorder() throws {
        try TestFixtures.withTempDirectory { parent in
            let map = try MapCatalog.decodeAndValidate(file: TestFixtures.inspectionMap)
            let created = try ProjectCreator(bookmarkStore: FakeBookmarkStore()).create(
                map: map,
                parent: parent,
                displayName: "Inspecao1"
            )
            let project = try ProjectOpener.open(url: created.url, maps: [map])
            let inbox = project.folderURL(for: try XCTUnwrap(map.inbox))

            let photoA = parent.appendingPathComponent("a.png")
            let photoB = parent.appendingPathComponent("b.png")
            let notes = parent.appendingPathComponent("readme.txt")
            try TestImageFactory.writePNG(width: 800, height: 600, to: photoA)
            try TestImageFactory.writePNG(width: 800, height: 600, to: photoB)
            try "nope".data(using: .utf8)!.write(to: notes)

            let stats = PhotoImporter().importFiles([photoA, photoB, notes], into: project)
            XCTAssertEqual(stats.imported, 2)
            XCTAssertEqual(stats.skipped, 1)
            XCTAssertTrue(FileManager.default.fileExists(atPath: photoA.path), "originals outside the project must stay")
            let inboxPhotos = try ProjectScanner.imageURLs(in: inbox)
            XCTAssertEqual(inboxPhotos.count, 2)
            XCTAssertTrue(inboxPhotos.allSatisfy { $0.pathExtension.lowercased() == "jpeg" })

            let organizer = FileOrganizer()
            let t10 = try XCTUnwrap(map.slot(folder: "T10"))
            let first = DiskPhoto(url: inboxPhotos[0], slotId: "inbox", fileName: inboxPhotos[0].lastPathComponent)
            let moved = try organizer.move(first, to: t10, in: project)
            XCTAssertTrue(moved.to.lastPathComponent.contains("_T10_1.jpeg"))
            XCTAssertFalse(FileManager.default.fileExists(atPath: first.url.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: moved.to.path))

            try organizer.undo(moved)
            XCTAssertTrue(FileManager.default.fileExists(atPath: moved.from.path))

            let t1 = try XCTUnwrap(map.slot(folder: "T1"))
            let remaining = try ProjectScanner.imageURLs(in: inbox)
            XCTAssertEqual(remaining.count, 2)
            _ = try organizer.move(DiskPhoto(url: remaining[0], slotId: "inbox", fileName: remaining[0].lastPathComponent), to: t1, in: project)
            _ = try organizer.move(DiskPhoto(url: remaining[1], slotId: "inbox", fileName: remaining[1].lastPathComponent), to: t1, in: project)
            let t1URLs = try ProjectScanner.imageURLs(in: project.folderURL(for: t1))
            XCTAssertEqual(t1URLs.count, 2)
            try organizer.reorder(urls: t1URLs, moving: 1, to: 0, project: project, slot: t1)
            let renamed = try ProjectScanner.imageURLs(in: project.folderURL(for: t1))
            XCTAssertEqual(renamed.map(\.lastPathComponent), ["Inspecao1_T1_1.jpeg", "Inspecao1_T1_2.jpeg"])
        }
    }
}

@MainActor
final class ProjectSessionTests: XCTestCase {
    func testSessionImportAndKeyboardClassification() async throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent("FastReportTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }

        let map = try MapCatalog.decodeAndValidate(file: TestFixtures.inspectionMap)
        let created = try ProjectCreator(bookmarkStore: FakeBookmarkStore()).create(
            map: map,
            parent: parent,
            displayName: "Dia 1"
        )
        let opened = try ProjectOpener.open(url: created.url, maps: [map])
        let session = ProjectSession(project: opened)
        let source = parent.appendingPathComponent("cam.png")
        try TestImageFactory.writePNG(width: 640, height: 480, to: source)
        await session.importURLs([source], locale: Locale(identifier: "pt"))
        XCTAssertEqual(session.inbox.count, 1)
        XCTAssertFalse(session.showsFolderReview)
        XCTAssertEqual(session.pendingCount, 1)
        XCTAssertFalse(session.showsFolderReview)

        session.startTriage()
        XCTAssertEqual(session.triageIndex + 1, 1)
        XCTAssertEqual(session.triagePhotos.count, 1)
        session.handleKey("2")
        session.handleKey("4")
        session.commitBuffer(locale: Locale(identifier: "pt"))
        XCTAssertEqual(session.photos(in: try XCTUnwrap(map.slot(folder: "T24"))).count, 1)
        XCTAssertEqual(session.inbox.count, 0)
        XCTAssertEqual(session.classifiedCount, 1)
        XCTAssertEqual(session.mode, .gallery)
        XCTAssertTrue(session.showsFolderReview)
        XCTAssertEqual(session.displaySlots().map(\.folder), ["T24"])

        session.undoLast(locale: Locale(identifier: "pt"))
        XCTAssertEqual(session.inbox.count, 1)
        session.close()
    }
}
