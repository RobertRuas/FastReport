import Foundation

struct Slot: Codable, Equatable, Identifiable, Sendable, Hashable {
    let id: String
    let folder: String
    let hotkeys: [String]
    let expectedCount: Int?
    let unlimited: Bool
    let isTrash: Bool
    let isInbox: Bool

    init(
        id: String,
        folder: String,
        hotkeys: [String] = [],
        expectedCount: Int? = nil,
        unlimited: Bool = false,
        isTrash: Bool = false,
        isInbox: Bool = false
    ) {
        self.id = id
        self.folder = folder
        self.hotkeys = hotkeys
        self.expectedCount = expectedCount
        self.unlimited = unlimited
        self.isTrash = isTrash
        self.isInbox = isInbox
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        folder = try container.decode(String.self, forKey: .folder)
        hotkeys = try container.decodeIfPresent([String].self, forKey: .hotkeys) ?? []
        expectedCount = try container.decodeIfPresent(Int.self, forKey: .expectedCount)
        isTrash = try container.decodeIfPresent(Bool.self, forKey: .isTrash) ?? false
        isInbox = try container.decodeIfPresent(Bool.self, forKey: .isInbox) ?? false
        if let unlimited = try container.decodeIfPresent(Bool.self, forKey: .unlimited) {
            self.unlimited = unlimited
        } else {
            unlimited = expectedCount == nil
        }
    }
}
