import XCTest
@testable import FastReport

final class OrganizationMapTests: XCTestCase {
    func testInspectionMapDecodesAndValidates() throws {
        let map = try MapCatalog.decodeAndValidate(file: TestFixtures.inspectionMap)
        XCTAssertEqual(map.id, "inspection-t24")
        XCTAssertEqual(map.version, 1)
        XCTAssertEqual(map.inboxFolder, "Inbox")
        XCTAssertEqual(map.fileNamePattern, "{project}_{slot}_{index}.jpeg")
        XCTAssertEqual(map.slots.count, 27)
        XCTAssertEqual(map.inbox?.folder, "Inbox")
        XCTAssertEqual(map.trash?.folder, "Trash")
        XCTAssertEqual(map.classificationSlots.count, 25)

        let tSlots = map.slots.filter { $0.id.hasPrefix("t") && !$0.isTrash && !$0.isInbox }
        XCTAssertEqual(tSlots.count, 24)
        XCTAssertTrue(tSlots.allSatisfy { $0.expectedCount == nil && $0.unlimited && $0.folder.hasPrefix("T") })
        XCTAssertEqual(map.name.resolved(language: .portuguese), "Inspeção T1–T24")
        XCTAssertEqual(map.name.resolved(language: .english), "Inspection T1–T24")
    }

    func testHotkeysResolveWithoutAmbiguityBetweenT1AndT10() throws {
        let map = try MapCatalog.decodeAndValidate(file: TestFixtures.inspectionMap)
        XCTAssertEqual(map.slot(matchingHotkey: "1")?.folder, "T1")
        XCTAssertEqual(map.slot(matchingHotkey: "10")?.folder, "T10")
        XCTAssertEqual(map.slot(matchingHotkey: "24")?.folder, "T24")
        XCTAssertEqual(map.slot(matchingHotkey: "0")?.folder, "General")
        XCTAssertEqual(map.slot(matchingHotkey: "G")?.folder, "General")
        XCTAssertEqual(map.slot(matchingHotkey: "cmd+backspace")?.isTrash, true)
        XCTAssertNil(map.slot(matchingHotkey: "   "))
        XCTAssertNil(map.slot(matchingHotkey: "25"))
        XCTAssertNil(map.slot(matchingHotkey: "t1"))
    }

    func testMissingOptionalSlotFieldsGetSafeDefaults() throws {
        let json = """
        {
          "id": "defaults",
          "version": 1,
          "name": { "pt": "Padrão", "en": "Default" },
          "fileNamePattern": "{project}_{slot}_{index}.jpeg",
          "inboxFolder": "Inbox",
          "slots": [
            { "id": "inbox", "folder": "Inbox", "isInbox": true },
            { "id": "general", "folder": "General" }
          ]
        }
        """.data(using: .utf8)!
        let map = try JSONDecoder().decode(OrganizationMap.self, from: json)
        XCTAssertEqual(map.inbox?.unlimited, true)
        XCTAssertEqual(map.slot(id: "general")?.hotkeys, [])
        XCTAssertEqual(map.slot(id: "general")?.isTrash, false)
        XCTAssertEqual(map.slot(id: "general")?.unlimited, true)
    }
}

final class MapValidatorTests: XCTestCase {
    func testInspectionMapHasNoValidationIssues() throws {
        let map = try MapCatalog.decodeAndValidate(file: TestFixtures.inspectionMap)
        XCTAssertEqual(MapValidator.issues(in: map), [])
    }

    func testRejectsDuplicateHotkeysAndMissingInbox() throws {
        try TestFixtures.withTempDirectory { directory in
            let url = directory.appendingPathComponent("bad.json")
            var json = validMapJSON()
            json["inboxFolder"] = "Inbox"
            var slots = json["slots"] as! [[String: Any]]
            slots.removeAll { ($0["id"] as? String) == "inbox" }
            slots.append([
                "id": "t1",
                "folder": "T1",
                "hotkeys": ["0"],
                "expectedCount": 7,
                "unlimited": false,
                "isInbox": false,
                "isTrash": false
            ])
            json["slots"] = slots
            try TestFixtures.writeJSON(json, to: url)

            XCTAssertThrowsError(try MapCatalog.decodeAndValidate(file: url)) { error in
                guard case MapCatalogError.invalid = error else {
                    return XCTFail("expected invalid, got \(error)")
                }
            }
        }
    }

    func testRejectsUnsafeFolderNames() {
        let map = OrganizationMap(
            id: "x",
            version: 1,
            name: LocalizedCopy(pt: "A", en: "A"),
            fileNamePattern: "{project}_{slot}_{index}.jpeg",
            inboxFolder: "../Inbox",
            slots: [
                Slot(id: "inbox", folder: "../Inbox", unlimited: true, isInbox: true)
            ]
        )
        let issues = MapValidator.issues(in: map)
        XCTAssertTrue(issues.contains(where: { $0.code == "error.map.inbox.folder" || $0.code == "error.slot.folder.invalid" }))
    }

    func testRejectsInboxAndTrashOnSameSlot() {
        let map = OrganizationMap(
            id: "x",
            version: 1,
            name: LocalizedCopy(pt: "A", en: "A"),
            fileNamePattern: "{project}_{slot}_{index}.jpeg",
            inboxFolder: "Inbox",
            slots: [
                Slot(id: "inbox", folder: "Inbox", unlimited: true, isTrash: true, isInbox: true)
            ]
        )
        XCTAssertTrue(MapValidator.issues(in: map).contains(where: { $0.code == "error.slot.role.conflict" }))
    }
}
