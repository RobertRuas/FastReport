import Foundation

enum ReviewDisplaySlots {
    static func partitions(map: OrganizationMap, occupiedIds: Set<String>) -> (special: [Slot], regular: [Slot]) {
        func occupied(_ slot: Slot) -> Bool { occupiedIds.contains(slot.id) }

        let numbered = map.slots
            .filter { $0.id.hasPrefix("t") && !$0.isTrash && !$0.isInbox && occupied($0) }
            .sorted { lhs, rhs in
                (Int(lhs.folder.dropFirst()) ?? 0) < (Int(rhs.folder.dropFirst()) ?? 0)
            }
        let general = map.slots.filter { $0.isGeneral && occupied($0) }
        let trash = map.slots.filter { $0.isTrash && occupied($0) }
        let inbox = map.slots.filter { $0.isInbox && occupied($0) }
        let numberedIDs = Set(numbered.map(\.id))
        let other = map.classificationSlots.filter { slot in
            occupied(slot) && !slot.isGeneral && !numberedIDs.contains(slot.id)
        }
        return (general + trash, numbered + other + inbox)
    }

    static func ordered(map: OrganizationMap, occupiedIds: Set<String>) -> [Slot] {
        let parts = partitions(map: map, occupiedIds: occupiedIds)
        return parts.special + parts.regular
    }

    static func deliveryPartitions(map: OrganizationMap, occupiedIds: Set<String>) -> (special: [Slot], regular: [Slot]) {
        let parts = partitions(map: map, occupiedIds: occupiedIds)
        return (
            parts.special.filter { !$0.isTrash },
            parts.regular.filter { !$0.isInbox }
        )
    }

    static func deliveryOrdered(map: OrganizationMap, occupiedIds: Set<String>) -> [Slot] {
        let parts = deliveryPartitions(map: map, occupiedIds: occupiedIds)
        return parts.special + parts.regular
    }

    static func title(_ slot: Slot, locale: Locale) -> String {
        if slot.isInbox {
            return String(localized: "workspace.inbox.label", locale: locale)
        }
        if slot.isGeneral {
            return String(localized: "workspace.slot.general", locale: locale)
        }
        if slot.isTrash {
            return String(localized: "workspace.slot.trash", locale: locale)
        }
        return slot.folder
    }
}
