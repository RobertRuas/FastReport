import Foundation

struct OrganizationMap: Codable, Equatable, Identifiable, Sendable, Hashable {
    let id: String
    let version: Int
    let name: LocalizedCopy
    let fileNamePattern: String
    let inboxFolder: String
    let slots: [Slot]

    var inbox: Slot? {
        slots.first(where: \.isInbox)
    }

    var trash: Slot? {
        slots.first(where: \.isTrash)
    }

    var classificationSlots: [Slot] {
        slots.filter { !$0.isInbox && !$0.isTrash }
    }

    func slot(id: String) -> Slot? {
        slots.first { $0.id == id }
    }

    func slot(folder: String) -> Slot? {
        slots.first { $0.folder == folder }
    }

    func slot(matchingHotkey hotkey: String) -> Slot? {
        let normalized = hotkey.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }
        return slots.first { slot in
            slot.hotkeys.contains { $0.lowercased() == normalized }
        }
    }
}
