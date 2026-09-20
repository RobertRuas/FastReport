import SwiftUI

struct LiveReorderStrip: View {
    let items: [DiskPhoto]
    let size: CGFloat
    let revision: Int
    var onTap: (DiskPhoto) -> Void
    var onRotate: ((DiskPhoto) -> Void)? = nil
    var onTrash: ((DiskPhoto) -> Void)? = nil
    var onCommitMove: (Int, Int) -> Void

    @State private var origin: [DiskPhoto] = []
    @State private var dragStartIndex: Int?
    @State private var translationX: CGFloat = 0

    private var cellWidth: CGFloat { size + ThumbnailSizeStore.spacing }

    private var layoutItems: [DiskPhoto] {
        origin.isEmpty ? items : origin
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
                ForEach(Array(layoutItems.enumerated()), id: \.element.id) { index, photo in
                    cell(index: index, photo: photo)
                }
            }
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

    private func cell(index: Int, photo: DiskPhoto) -> some View {
        let dragged = dragStartIndex.map { $0 == index } ?? false
        let shift: CGFloat = {
            guard let start = dragStartIndex, !dragged else { return dragged ? translationX : 0 }
            return LiveReorderLayout.neighborOffset(
                index: index,
                dragIndex: start,
                targetIndex: currentTargetIndex,
                cellWidth: cellWidth
            )
        }()

        return ThumbnailView(
            url: photo.url,
            size: size,
            revision: revision,
            onRotate: onRotate.map { action in { action(photo) } },
            onTrash: onTrash.map { action in { action(photo) } }
        )
            .shadow(color: dragged ? Color.black.opacity(0.22) : .clear, radius: dragged ? 8 : 0, y: dragged ? 3 : 0)
            .scaleEffect(dragged ? 1.05 : 1)
            .offset(x: dragged ? translationX : shift)
            .zIndex(dragged ? 10 : 0)
            .animation(dragged ? nil : .interactiveSpring(response: 0.32, dampingFraction: 0.9), value: currentTargetIndex)
            .gesture(dragGesture(for: photo))
            .onTapGesture { onTap(photo) }
            .hoverHint(verbatim: photo.fileName)
    }

    private func dragGesture(for photo: DiskPhoto) -> some Gesture {
        DragGesture(minimumDistance: 6)
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
