import Foundation

struct ClassificationBuffer: Equatable, Sendable {
    private(set) var text = ""

    var preview: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }
        if trimmed == "0" || trimmed.lowercased() == "g" { return "General" }
        if let value = Int(trimmed), (1...99).contains(value) {
            return "T\(value)"
        }
        return trimmed.uppercased()
    }

    mutating func append(_ character: Character) {
        let scalar = String(character).lowercased()
        if scalar == "g" {
            text = "g"
            return
        }
        guard character.isNumber else { return }
        if text == "g" { text = "" }
        if text.count >= 2 { return }
        text.append(character)
    }

    mutating func clear() {
        text = ""
    }

    func slot(in map: OrganizationMap) -> Slot? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        return map.slot(matchingHotkey: trimmed)
    }
}
