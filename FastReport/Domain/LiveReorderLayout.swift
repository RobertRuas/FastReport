import Foundation

enum LiveReorderLayout {
    static func targetIndex(
        from startIndex: Int,
        translationX: CGFloat,
        cellWidth: CGFloat,
        count: Int
    ) -> Int {
        guard count > 0 else { return 0 }
        guard cellWidth > 0 else { return min(max(startIndex, 0), count - 1) }
        let delta = Int((translationX / cellWidth).rounded())
        return min(max(startIndex + delta, 0), count - 1)
    }

    static func movingItem<T>(in items: [T], from: Int, to: Int) -> [T] {
        guard items.indices.contains(from), items.indices.contains(to), from != to else { return items }
        var ordered = items
        let item = ordered.remove(at: from)
        ordered.insert(item, at: to)
        return ordered
    }

    static func residualOffset(translationX: CGFloat, from: Int, to: Int, cellWidth: CGFloat) -> CGFloat {
        translationX - CGFloat(to - from) * cellWidth
    }
}
