import SwiftUI

struct LiveReorderStrip: View {
    let items: [DiskPhoto]
    let size: CGFloat
    let revision: Int
    var onTap: (DiskPhoto) -> Void
    var onCommitMove: (Int, Int) -> Void

    @State private var origin: [DiskPhoto] = []
    @State private var dragStartIndex: Int?
    @State private var translationX: CGFloat = 0

    private var cellWidth: CGFloat { size + ThumbnailSizeStore.spacing }

    private var displayed: [DiskPhoto] {
        if let start = dragStartIndex {
            return LiveReorderLayout.movingItem(in: origin, from: start, to: currentTargetIndex)
        }
        return origin.isEmpty ? items : origin
    }

    private var currentTargetIndex: Int {
        guard let start = dragStartIndex else { return 0 }
        return LiveReorderLayout.targetIndex(
            from: start,
            translationX: translationX,
            cellWidth: cellWidth,
            count: origin.count
        )
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ThumbnailSizeStore.spacing) {
                ForEach(displayed) { photo in
                    cell(for: photo)
                }
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: displayed.map(\.id))
            .padding(.vertical, 8)
            .padding(.horizontal, 2)
        }
        .scrollDisabled(dragStartIndex != nil)
        .onAppear { origin = items }
        .onChange(of: items.map(\.id)) { _, _ in
            if dragStartIndex == nil {
                origin = items
            }
        }
    }

    private func cell(for photo: DiskPhoto) -> some View {
        let dragged = dragStartIndex.map { origin.indices.contains($0) && origin[$0].id == photo.id } ?? false
        let residual: CGFloat = {
            guard dragged, let start = dragStartIndex else { return 0 }
            return LiveReorderLayout.residualOffset(
                translationX: translationX,
                from: start,
                to: currentTargetIndex,
                cellWidth: cellWidth
            )
        }()

        return ThumbnailView(url: photo.url, size: size, revision: revision)
            .shadow(color: dragged ? Color.black.opacity(0.28) : .clear, radius: dragged ? 10 : 0, y: dragged ? 4 : 0)
            .scaleEffect(dragged ? 1.08 : 1)
            .offset(x: residual)
            .zIndex(dragged ? 1 : 0)
            .gesture(dragGesture(for: photo))
            .onTapGesture { onTap(photo) }
            .hoverHint(verbatim: photo.fileName)
    }

    private func dragGesture(for photo: DiskPhoto) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if dragStartIndex == nil {
                    origin = items
                    dragStartIndex = origin.firstIndex(where: { $0.id == photo.id })
                }
                translationX = value.translation.width
            }
            .onEnded { _ in
                let start = dragStartIndex
                let target = currentTargetIndex
                if let start, start != target {
                    origin = LiveReorderLayout.movingItem(in: origin, from: start, to: target)
                    onCommitMove(start, target)
                }
                dragStartIndex = nil
                translationX = 0
            }
    }
}
