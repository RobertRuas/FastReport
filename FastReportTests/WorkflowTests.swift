import CoreGraphics
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

    func testFlipHorizontalMirrorsLeftAndRight() throws {
        try TestFixtures.withTempDirectory { directory in
            let source = directory.appendingPathComponent("split.png")
            let jpeg = directory.appendingPathComponent("split.jpeg")
            try TestImageFactory.writeSplitPNG(width: 400, height: 200, to: source)
            try ImagePipeline.convertToJPEG(source: source, destination: jpeg, settings: ImageExportSettings(maxDimension: 400, quality: 1))
            let before = try XCTUnwrap(redSamples(of: jpeg))
            XCTAssertGreaterThan(before.left, 180)
            XCTAssertLessThan(before.right, 40)
            try ImagePipeline.flipHorizontal(at: jpeg, settings: ImageExportSettings(maxDimension: 400, quality: 1))
            let size = try XCTUnwrap(ImagePipeline.pixelSize(of: jpeg))
            XCTAssertEqual(size.0, 400)
            XCTAssertEqual(size.1, 200)
            let after = try XCTUnwrap(redSamples(of: jpeg))
            XCTAssertLessThan(after.left, 40)
            XCTAssertGreaterThan(after.right, 180)
        }
    }

    func testCropKeepsLeftHalf() throws {
        try TestFixtures.withTempDirectory { directory in
            let source = directory.appendingPathComponent("split.png")
            let jpeg = directory.appendingPathComponent("split.jpeg")
            try TestImageFactory.writeSplitPNG(width: 400, height: 200, to: source)
            try ImagePipeline.convertToJPEG(
                source: source,
                destination: jpeg,
                settings: ImageExportSettings(maxDimension: 400, quality: 1)
            )
            try ImagePipeline.crop(
                at: jpeg,
                normalized: CGRect(x: 0, y: 0, width: 0.5, height: 1),
                settings: ImageExportSettings(maxDimension: 400, quality: 1)
            )
            let size = try XCTUnwrap(ImagePipeline.pixelSize(of: jpeg))
            XCTAssertEqual(size.0, 200)
            XCTAssertEqual(size.1, 200)
            let samples = try XCTUnwrap(redSamples(of: jpeg))
            XCTAssertGreaterThan(samples.left, 180)
            XCTAssertGreaterThan(samples.right, 180)
        }
    }

    private func redSamples(of url: URL) -> (left: UInt8, right: UInt8)? {
        guard let image = ImagePipeline.thumbnail(from: url, maxPixelSize: 400) else { return nil }
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        var data = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * bytesPerPixel,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let y = height / 2
        let left = data[(y * width + 8) * bytesPerPixel]
        let right = data[(y * width + (width - 9)) * bytesPerPixel]
        return (left, right)
    }
}

final class PhotoCropGeometryTests: XCTestCase {
    func testClampAndSouthEastDragStayInsideUnitSquare() {
        let overflow = PhotoCropGeometry.clamp(CGRect(x: -0.2, y: 0.3, width: 2, height: 0.9))
        XCTAssertEqual(overflow.origin.x, 0, accuracy: 0.0001)
        XCTAssertEqual(overflow.width, 1, accuracy: 0.0001)
        XCTAssertGreaterThanOrEqual(overflow.minY, 0)
        XCTAssertLessThanOrEqual(overflow.maxY, 1)

        let dragged = PhotoCropGeometry.apply(
            handle: .southEast,
            to: CGRect(x: 0.2, y: 0.2, width: 0.3, height: 0.3),
            dx: 1,
            dy: 1
        )
        XCTAssertEqual(dragged.maxX, 1, accuracy: 0.0001)
        XCTAssertEqual(dragged.maxY, 1, accuracy: 0.0001)
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
        XCTAssertTrue(SparkleInstallError.isUnupdatableLocation(NSError(domain: "SUSparkleErrorDomain", code: 1003)))
        XCTAssertTrue(SparkleInstallError.isUnupdatableLocation(NSError(domain: "SUSparkleErrorDomain", code: 1005)))
        XCTAssertTrue(SparkleInstallError.isNoUpdate(NSError(domain: "SUSparkleErrorDomain", code: 1001)))
        let pt = Locale(identifier: "pt")
        XCTAssertEqual(
            SparkleInstallError.message(for: NSError(domain: "SUSparkleErrorDomain", code: 1005), locale: pt),
            String(localized: "error.updates.location", locale: pt)
        )
        XCTAssertEqual(
            SparkleInstallError.message(for: NSError(domain: "NSURLErrorDomain", code: -1009), locale: pt),
            String(localized: "error.updates.network", locale: pt)
        )
        XCTAssertEqual(
            SparkleInstallError.message(for: NSError(domain: "SUSparkleErrorDomain", code: 3001), locale: pt),
            String(localized: "error.updates.signature", locale: pt)
        )
    }

    func testDetectsTranslocatedAndCopiesAppBundle() throws {
        let translocated = URL(fileURLWithPath: "/private/var/folders/xx/T/AppTranslocation/ABCD/d/FastReport.app")
        XCTAssertEqual(AppInstallLocation.diagnose(bundleURL: translocated), .translocated)
        XCTAssertTrue(AppInstallLocation.diagnose(bundleURL: translocated).blocksUpdates)

        try TestFixtures.withTempDirectory { directory in
            let source = directory.appendingPathComponent("FastReport.app")
            let destination = directory.appendingPathComponent("Applications/FastReport.app")
            try FileManager.default.createDirectory(at: source.appendingPathComponent("Contents"), withIntermediateDirectories: true)
            try "ok".write(to: source.appendingPathComponent("Contents/Info.plist"), atomically: true, encoding: .utf8)
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try ApplicationMover.copyToApplications(from: source, destination: destination)
            XCTAssertTrue(FileManager.default.fileExists(atPath: destination.appendingPathComponent("Contents/Info.plist").path))
            try "v2".write(to: source.appendingPathComponent("Contents/Info.plist"), atomically: true, encoding: .utf8)
            try ApplicationMover.copyToApplications(from: source, destination: destination)
            XCTAssertEqual(try String(contentsOf: destination.appendingPathComponent("Contents/Info.plist")), "v2")
        }
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

    func testEmptyTrashMovesFilesToFinderTrashDestination() throws {
        try TestFixtures.withTempDirectory { parent in
            let map = try MapCatalog.decodeAndValidate(file: TestFixtures.inspectionMap)
            let created = try ProjectCreator(bookmarkStore: FakeBookmarkStore()).create(
                map: map,
                parent: parent,
                displayName: "Inspecao1"
            )
            let project = try ProjectOpener.open(url: created.url, maps: [map])
            let inbox = project.folderURL(for: try XCTUnwrap(map.inbox))
            let source = parent.appendingPathComponent("a.png")
            try TestImageFactory.writePNG(width: 400, height: 300, to: source)
            XCTAssertEqual(PhotoImporter().importFiles([source], into: project).imported, 1)

            let finderTrash = parent.appendingPathComponent("FinderTrash", isDirectory: true)
            try FileManager.default.createDirectory(at: finderTrash, withIntermediateDirectories: true)
            var organizer = FileOrganizer()
            organizer.moveToFinderTrash = { url in
                try FileManager.default.moveItem(
                    at: url,
                    to: finderTrash.appendingPathComponent(url.lastPathComponent)
                )
            }

            let inboxPhotos = try ProjectScanner.imageURLs(in: inbox)
            XCTAssertEqual(inboxPhotos.count, 1)
            let trash = try XCTUnwrap(map.trash)
            let moved = try organizer.move(
                DiskPhoto(url: inboxPhotos[0], slotId: "inbox", fileName: inboxPhotos[0].lastPathComponent),
                to: trash,
                in: project
            )
            try organizer.emptyTrash([
                DiskPhoto(url: moved.to, slotId: trash.id, fileName: moved.to.lastPathComponent)
            ])
            XCTAssertFalse(FileManager.default.fileExists(atPath: moved.to.path))
            XCTAssertTrue(
                FileManager.default.fileExists(
                    atPath: finderTrash.appendingPathComponent(moved.to.lastPathComponent).path
                )
            )
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

    func testEmptyTrashClearsTrashAfterConfirmationPath() async throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent("FastReportTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }

        let map = try MapCatalog.decodeAndValidate(file: TestFixtures.inspectionMap)
        let created = try ProjectCreator(bookmarkStore: FakeBookmarkStore()).create(
            map: map,
            parent: parent,
            displayName: "Dia 2"
        )
        let opened = try ProjectOpener.open(url: created.url, maps: [map])
        let finderTrash = parent.appendingPathComponent("FinderTrash", isDirectory: true)
        try FileManager.default.createDirectory(at: finderTrash, withIntermediateDirectories: true)
        var organizer = FileOrganizer()
        organizer.moveToFinderTrash = { url in
            try FileManager.default.moveItem(
                at: url,
                to: finderTrash.appendingPathComponent(url.lastPathComponent)
            )
        }

        let session = ProjectSession(project: opened, organizer: organizer)
        let source = parent.appendingPathComponent("cam.png")
        try TestImageFactory.writePNG(width: 640, height: 480, to: source)
        await session.importURLs([source], locale: Locale(identifier: "pt"))
        session.startTriage()
        session.handleKey("1")
        session.commitBuffer(locale: Locale(identifier: "pt"))
        let classified = try XCTUnwrap(session.photos(in: try XCTUnwrap(map.slot(folder: "T1"))).first)
        session.trash(classified, locale: Locale(identifier: "pt"))
        XCTAssertTrue(session.hasTrashItems)
        XCTAssertEqual(session.photos(in: try XCTUnwrap(map.trash)).count, 1)

        session.emptyTrash(locale: Locale(identifier: "pt"))
        XCTAssertFalse(session.hasTrashItems)
        XCTAssertEqual(session.photos(in: try XCTUnwrap(map.trash)).count, 0)
        XCTAssertEqual(session.classifiedCount, 0)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(at: finderTrash, includingPropertiesForKeys: nil).count, 1)
        session.close()
    }
}

final class ProjectOpenerTests: XCTestCase {
    func testOpensVisibleIndexAndMigratesLegacyHiddenFile() throws {
        try TestFixtures.withTempDirectory { parent in
            let map = try MapCatalog.decodeAndValidate(file: TestFixtures.inspectionMap)
            let created = try ProjectCreator(bookmarkStore: FakeBookmarkStore()).create(
                map: map,
                parent: parent,
                displayName: "Aberto"
            )
            let visible = created.url.appendingPathComponent(ProjectMetadata.fileName)
            XCTAssertTrue(FileManager.default.fileExists(atPath: visible.path))
            let opened = try ProjectOpener.open(url: created.url, maps: [map])
            XCTAssertEqual(opened.metadata.displayName, "Aberto")

            let legacy = created.url.appendingPathComponent(ProjectMetadata.legacyFileName)
            try FileManager.default.moveItem(at: visible, to: legacy)
            XCTAssertFalse(FileManager.default.fileExists(atPath: visible.path))
            let migrated = try ProjectOpener.open(url: created.url, maps: [map])
            XCTAssertEqual(migrated.metadata.displayName, "Aberto")
            XCTAssertTrue(FileManager.default.fileExists(atPath: visible.path))
        }
    }

    func testRejectsFolderWithoutIndex() throws {
        try TestFixtures.withTempDirectory { directory in
            XCTAssertThrowsError(try ProjectOpener.open(url: directory, maps: [])) { error in
                XCTAssertEqual(error as? ProjectOpenError, .missingMetadata)
            }
        }
    }
}
