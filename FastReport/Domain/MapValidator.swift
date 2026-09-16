import Foundation

struct MapValidationIssue: Equatable, Sendable, Hashable {
    let code: String
    let rawMessage: String

    func localized(locale: Locale) -> String {
        String(localized: String.LocalizationValue(code), locale: locale)
    }
}

struct MapValidationError: Error, Equatable {
    let mapId: String
    let issues: [MapValidationIssue]

    func localized(locale: Locale) -> String {
        let prefix = String(localized: "error.map.invalid", locale: locale)
        let details = issues.map { $0.localized(locale: locale) }.joined(separator: " ")
        return details.isEmpty ? prefix : "\(prefix) \(details)"
    }
}

enum MapValidator {
    static let requiredPatternTokens = ["{project}", "{slot}", "{index}"]

    static func validate(_ map: OrganizationMap) throws {
        let issues = issues(in: map)
        if !issues.isEmpty {
            throw MapValidationError(mapId: map.id, issues: issues)
        }
    }

    static func issues(in map: OrganizationMap) -> [MapValidationIssue] {
        var issues: [MapValidationIssue] = []

        if map.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(code: "error.map.id.empty", rawMessage: "empty id"))
        }
        if map.version < 1 {
            issues.append(.init(code: "error.map.version", rawMessage: "version \(map.version)"))
        }
        if map.name.validated() != nil {
            issues.append(.init(code: "error.map.name", rawMessage: "empty name"))
        }
        if map.fileNamePattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(code: "error.map.pattern.empty", rawMessage: "empty pattern"))
        } else {
            for token in requiredPatternTokens where !map.fileNamePattern.contains(token) {
                issues.append(.init(code: "error.map.pattern.token", rawMessage: "missing \(token)"))
            }
        }

        let inboxFolder = map.inboxFolder.trimmingCharacters(in: .whitespacesAndNewlines)
        if inboxFolder.isEmpty || !isSafeFolderName(inboxFolder) {
            issues.append(.init(code: "error.map.inbox.folder", rawMessage: "bad inbox folder"))
        }
        if map.slots.isEmpty {
            issues.append(.init(code: "error.map.slots.empty", rawMessage: "no slots"))
            return issues
        }

        var seenIds = Set<String>()
        var seenFolders = Set<String>()
        var seenHotkeys = Set<String>()
        var inboxCount = 0
        var trashCount = 0

        for slot in map.slots {
            let id = slot.id.trimmingCharacters(in: .whitespacesAndNewlines)
            let folder = slot.folder.trimmingCharacters(in: .whitespacesAndNewlines)

            if id.isEmpty {
                issues.append(.init(code: "error.slot.id.empty", rawMessage: "empty slot id"))
            } else if !seenIds.insert(id).inserted {
                issues.append(.init(code: "error.slot.id.duplicate", rawMessage: "duplicate id \(id)"))
            }

            if folder.isEmpty || !isSafeFolderName(folder) {
                issues.append(.init(code: "error.slot.folder.invalid", rawMessage: "bad folder \(folder)"))
            } else if !seenFolders.insert(folder).inserted {
                issues.append(.init(code: "error.slot.folder.duplicate", rawMessage: "duplicate folder \(folder)"))
            }

            if slot.isInbox { inboxCount += 1 }
            if slot.isTrash { trashCount += 1 }
            if slot.isInbox && slot.isTrash {
                issues.append(.init(code: "error.slot.role.conflict", rawMessage: "inbox+trash \(id)"))
            }

            if let expected = slot.expectedCount, expected < 1 {
                issues.append(.init(code: "error.slot.expected", rawMessage: "expectedCount \(expected)"))
            }
            if !slot.unlimited, slot.expectedCount == nil, !slot.isInbox, !slot.isTrash {
                issues.append(.init(code: "error.slot.expected.missing", rawMessage: "missing expectedCount \(id)"))
            }

            for hotkey in slot.hotkeys {
                let key = hotkey.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if key.isEmpty {
                    issues.append(.init(code: "error.slot.hotkey.empty", rawMessage: "empty hotkey in \(id)"))
                    continue
                }
                if !seenHotkeys.insert(key).inserted {
                    issues.append(.init(code: "error.slot.hotkey.duplicate", rawMessage: "duplicate hotkey \(key)"))
                }
            }
        }

        if inboxCount != 1 {
            issues.append(.init(code: "error.map.inbox.count", rawMessage: "inbox count \(inboxCount)"))
        } else if let inbox = map.inbox, inbox.folder != inboxFolder {
            issues.append(.init(code: "error.map.inbox.mismatch", rawMessage: "inbox folder mismatch"))
        }

        if trashCount > 1 {
            issues.append(.init(code: "error.map.trash.count", rawMessage: "trash count \(trashCount)"))
        }

        return issues
    }

    static func isSafeFolderName(_ name: String) -> Bool {
        if name.isEmpty { return false }
        if name == "." || name == ".." { return false }
        if name.contains("/") || name.contains("\\") || name.contains(":") { return false }
        if name.contains("\0") { return false }
        if name.hasPrefix(".") { return false }
        return true
    }
}
