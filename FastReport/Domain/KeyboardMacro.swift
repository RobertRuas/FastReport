import CoreGraphics
import Foundation

struct KeyboardMacroEvent: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case key
        case mouseMove
        case mouseDown
        case mouseUp
    }

    var kind: Kind
    var keyCode: UInt16
    var flags: UInt64
    var delayNanoseconds: UInt64
    var isKeyDown: Bool
    var x: Double
    var y: Double
    var clickCount: Int

    init(
        kind: Kind = .key,
        keyCode: UInt16 = 0,
        flags: UInt64 = 0,
        delayNanoseconds: UInt64 = 0,
        isKeyDown: Bool = true,
        x: Double = 0,
        y: Double = 0,
        clickCount: Int = 1
    ) {
        self.kind = kind
        self.keyCode = keyCode
        self.flags = flags
        self.delayNanoseconds = delayNanoseconds
        self.isKeyDown = isKeyDown
        self.x = x
        self.y = y
        self.clickCount = clickCount
    }

    init(keyCode: UInt16, flags: UInt64, delayNanoseconds: UInt64 = 0, isKeyDown: Bool) {
        self.init(kind: .key, keyCode: keyCode, flags: flags, delayNanoseconds: delayNanoseconds, isKeyDown: isKeyDown)
    }

    var cgFlags: CGEventFlags { CGEventFlags(rawValue: flags) }
    var point: CGPoint { CGPoint(x: x, y: y) }

    var isModifierKey: Bool {
        kind == .key && Self.modifierKeyCodes.contains(keyCode)
    }

    var isPlaybackStep: Bool {
        switch kind {
        case .key:
            return isKeyDown && !isModifierKey
        case .mouseDown, .mouseMove:
            return true
        case .mouseUp:
            return false
        }
    }

    static let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 58, 59, 60, 61, 62, 63]
    static let minStepDelayMs = 50
    static let maxStepDelayMs = 1_000
    static let defaultStepDelayMs = 150

    static func clampedStepDelayMs(_ value: Int) -> Int {
        min(max(value, minStepDelayMs), maxStepDelayMs)
    }

    static func key(code: UInt16, flags: UInt64, down: Bool) -> KeyboardMacroEvent {
        KeyboardMacroEvent(kind: .key, keyCode: code, flags: flags, isKeyDown: down)
    }

    static func mouseMove(to point: CGPoint) -> KeyboardMacroEvent {
        KeyboardMacroEvent(kind: .mouseMove, x: point.x, y: point.y)
    }

    static func mouseDown(at point: CGPoint, count: Int) -> KeyboardMacroEvent {
        KeyboardMacroEvent(kind: .mouseDown, x: point.x, y: point.y, clickCount: max(count, 1))
    }

    static func mouseUp(at point: CGPoint, count: Int) -> KeyboardMacroEvent {
        KeyboardMacroEvent(kind: .mouseUp, x: point.x, y: point.y, clickCount: max(count, 1))
    }

    private enum CodingKeys: String, CodingKey {
        case kind, keyCode, flags, delayNanoseconds, isKeyDown, x, y, clickCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decodeIfPresent(Kind.self, forKey: .kind) ?? .key
        keyCode = try container.decodeIfPresent(UInt16.self, forKey: .keyCode) ?? 0
        flags = try container.decodeIfPresent(UInt64.self, forKey: .flags) ?? 0
        delayNanoseconds = try container.decodeIfPresent(UInt64.self, forKey: .delayNanoseconds) ?? 0
        isKeyDown = try container.decodeIfPresent(Bool.self, forKey: .isKeyDown) ?? (kind == .key)
        x = try container.decodeIfPresent(Double.self, forKey: .x) ?? 0
        y = try container.decodeIfPresent(Double.self, forKey: .y) ?? 0
        clickCount = try container.decodeIfPresent(Int.self, forKey: .clickCount) ?? 1
    }
}

struct KeyboardMacro: Codable, Equatable, Sendable {
    var events: [KeyboardMacroEvent]
    var recordedAt: Date
}

struct StoredMacro: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var events: [KeyboardMacroEvent]
    var recordedAt: Date
    var projectPath: String?

    var isGlobal: Bool { projectPath == nil }
    var isEmpty: Bool { events.isEmpty }

    func makingGlobal(name: String) -> StoredMacro {
        var copy = self
        copy.name = Self.normalizedName(name)
        copy.projectPath = nil
        return copy
    }

    static func normalizedName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Macro" : String(trimmed.prefix(80))
    }

    static func removing(projectPath path: String, from macros: [StoredMacro]) -> [StoredMacro] {
        macros.filter { $0.projectPath != path }
    }

    static func available(in macros: [StoredMacro], projectPath: String?) -> [StoredMacro] {
        macros.filter { macro in
            macro.isGlobal || macro.projectPath == projectPath
        }
        .sorted { lhs, rhs in
            if lhs.isGlobal != rhs.isGlobal { return lhs.isGlobal && !rhs.isGlobal }
            return lhs.recordedAt > rhs.recordedAt
        }
    }
}

struct MacroLibraryFile: Codable, Equatable, Sendable {
    var macros: [StoredMacro]
}

struct MacroChip: Identifiable, Equatable, Sendable {
    var id: Int
    var eventIndex: Int
    var eventCount: Int
    var kind: Kind

    var stepNumber: Int { id + 1 }
    var cocoaPoint: CGPoint? {
        guard case .click(let x, let y) = kind else { return nil }
        return CGPoint(x: x, y: y)
    }

    enum Kind: Equatable, Sendable {
        case key(parts: [String])
        case click(x: Int, y: Int)
    }
}

enum MacroSequence {
    static func keyEvents(code: UInt16, flags: UInt64) -> [KeyboardMacroEvent] {
        [
            .key(code: code, flags: flags, down: true),
            .key(code: code, flags: flags, down: false)
        ]
    }

    static func clickEvents(at point: CGPoint, count: Int = 1) -> [KeyboardMacroEvent] {
        [
            .mouseMove(to: point),
            .mouseDown(at: point, count: count),
            .mouseUp(at: point, count: count)
        ]
    }

    static func inserting(
        _ addition: [KeyboardMacroEvent],
        in events: [KeyboardMacroEvent],
        atEventIndex index: Int
    ) -> [KeyboardMacroEvent] {
        guard !addition.isEmpty else { return events }
        let clamped = min(max(index, 0), events.count)
        var next = events
        next.insert(contentsOf: addition, at: clamped)
        return next
    }

    static func removingStep(
        in events: [KeyboardMacroEvent],
        chip: MacroChip
    ) -> [KeyboardMacroEvent] {
        guard chip.eventCount > 0,
              events.indices.contains(chip.eventIndex),
              chip.eventIndex + chip.eventCount <= events.count
        else { return events }
        var next = events
        next.removeSubrange(chip.eventIndex ..< (chip.eventIndex + chip.eventCount))
        return next
    }

    static func movingClick(
        in events: [KeyboardMacroEvent],
        chip: MacroChip,
        to point: CGPoint
    ) -> [KeyboardMacroEvent] {
        guard chip.eventCount > 0,
              events.indices.contains(chip.eventIndex),
              chip.eventIndex + chip.eventCount <= events.count
        else { return events }
        var next = events
        for offset in 0 ..< chip.eventCount {
            let index = chip.eventIndex + offset
            switch next[index].kind {
            case .mouseMove, .mouseDown, .mouseUp:
                next[index].x = point.x
                next[index].y = point.y
            default:
                break
            }
        }
        return next
    }

    static func movingStep(
        in events: [KeyboardMacroEvent],
        chip: MacroChip,
        offset: Int
    ) -> [KeyboardMacroEvent] {
        let all = MacroDisplay.chips(from: events)
        guard let fromIndex = all.firstIndex(where: { $0.id == chip.id }) else { return events }
        let toIndex = fromIndex + offset
        guard toIndex != fromIndex, all.indices.contains(toIndex) else { return events }
        var next = events
        let block = Array(next[chip.eventIndex ..< (chip.eventIndex + chip.eventCount)])
        next.removeSubrange(chip.eventIndex ..< (chip.eventIndex + chip.eventCount))
        let remaining = MacroDisplay.chips(from: next)
        let insertAt: Int
        if toIndex >= remaining.count {
            insertAt = next.count
        } else {
            insertAt = remaining[toIndex].eventIndex
        }
        next.insert(contentsOf: block, at: insertAt)
        return next
    }

    static func replacingStep(
        in events: [KeyboardMacroEvent],
        chip: MacroChip,
        with addition: [KeyboardMacroEvent]
    ) -> [KeyboardMacroEvent] {
        let removed = removingStep(in: events, chip: chip)
        return inserting(addition, in: removed, atEventIndex: min(chip.eventIndex, removed.count))
    }
}

enum MacroDisplay {
    static func chips(from events: [KeyboardMacroEvent]) -> [MacroChip] {
        var chips: [MacroChip] = []
        var index = 0
        var i = 0
        while i < events.count {
            let event = events[i]
            switch event.kind {
            case .key where event.isKeyDown && !event.isModifierKey:
                var count = 1
                if i + 1 < events.count {
                    let next = events[i + 1]
                    if next.kind == .key, !next.isKeyDown, next.keyCode == event.keyCode {
                        count = 2
                    }
                }
                chips.append(
                    MacroChip(
                        id: index,
                        eventIndex: i,
                        eventCount: count,
                        kind: .key(parts: keyParts(for: event))
                    )
                )
                index += 1
                i += 1
            case .mouseDown:
                var start = i
                var count = 1
                if i > 0, events[i - 1].kind == .mouseMove {
                    start = i - 1
                    count = 2
                }
                let downIndex = i
                if downIndex + 1 < events.count, events[downIndex + 1].kind == .mouseUp {
                    count = downIndex - start + 2
                }
                chips.append(
                    MacroChip(
                        id: index,
                        eventIndex: start,
                        eventCount: count,
                        kind: .click(x: Int(event.x.rounded()), y: Int(event.y.rounded()))
                    )
                )
                index += 1
                i += 1
            default:
                i += 1
            }
        }
        return chips
    }

    static func keyParts(for event: KeyboardMacroEvent) -> [String] {
        var parts: [String] = []
        let flags = event.cgFlags
        if flags.contains(.maskControl) { parts.append("⌃") }
        if flags.contains(.maskAlternate) { parts.append("⌥") }
        if flags.contains(.maskShift) { parts.append("⇧") }
        if flags.contains(.maskCommand) { parts.append("⌘") }
        parts.append(KeyCodeGlyph.label(for: event.keyCode))
        return parts
    }

    static func suggestedGlobalName(from current: String) -> String {
        let base = StoredMacro.normalizedName(current)
        if base.localizedCaseInsensitiveContains("global") {
            return base
        }
        return "Global — \(base)"
    }
}

enum KeyCodeGlyph {
    static func label(for keyCode: UInt16) -> String {
        switch keyCode {
        case 36, 76: return "↵"
        case 48: return "⇥"
        case 49: return "␣"
        case 51: return "⌫"
        case 53: return "esc"
        case 117: return "⌦"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        case 115: return "↖"
        case 119: return "↘"
        case 116: return "⇞"
        case 121: return "⇟"
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        case 71: return "⌧"
        default:
            return KeyLayout.translate(keyCode) ?? String(keyCode)
        }
    }
}
