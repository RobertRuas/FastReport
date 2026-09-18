import SwiftUI

enum HoverHintPlacement {
    case below
    case above
}

@MainActor
@Observable
final class HoverHintStore {
    static let space = "fastreport.hoverHint"

    var isVisible = false
    var showDetail = false
    var title = Text("")
    var hint: Text?
    var anchor: CGRect = .zero
    var preferredPlacement: HoverHintPlacement = .below

    @ObservationIgnored private var session: UUID?

    func present(
        session: UUID,
        title: Text,
        hint: Text?,
        anchor: CGRect,
        placement: HoverHintPlacement
    ) {
        self.session = session
        self.title = title
        self.hint = hint
        self.anchor = anchor
        self.preferredPlacement = placement
        isVisible = true
    }

    func move(session: UUID, anchor: CGRect) {
        guard self.session == session else { return }
        self.anchor = anchor
    }

    func revealDetail(session: UUID) {
        guard self.session == session, isVisible else { return }
        showDetail = true
    }

    func dismiss(session: UUID) {
        guard self.session == session else { return }
        isVisible = false
        showDetail = false
        self.session = nil
    }
}

struct HoverHintModifier: ViewModifier {
    var title: Text
    var hint: Text?
    var placement: HoverHintPlacement = .below

    @Environment(HoverHintStore.self) private var store
    @State private var session = UUID()
    @State private var lastFrame: CGRect = .zero
    @State private var titleTask: Task<Void, Never>?
    @State private var hintTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            lastFrame = geo.frame(in: .named(HoverHintStore.space))
                        }
                        .onChange(of: geo.frame(in: .named(HoverHintStore.space))) { _, frame in
                            lastFrame = frame
                            store.move(session: session, anchor: frame)
                        }
                }
            }
            .onHover { hovering in
                handleHover(hovering, anchor: lastFrame)
            }
            .onDisappear {
                cancelTasks()
                store.dismiss(session: session)
            }
    }

    private func handleHover(_ hovering: Bool, anchor: CGRect) {
        cancelTasks()
        guard hovering else {
            store.dismiss(session: session)
            return
        }
        let current = session
        titleTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(140))
            guard !Task.isCancelled else { return }
            store.present(session: current, title: title, hint: hint, anchor: anchor, placement: placement)
        }
        guard hint != nil else { return }
        hintTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                store.revealDetail(session: current)
            }
        }
    }

    private func cancelTasks() {
        titleTask?.cancel()
        hintTask?.cancel()
        titleTask = nil
        hintTask = nil
    }
}

struct HoverHintCanvas: View {
    @Environment(HoverHintStore.self) private var store
    @State private var bubbleSize = CGSize(width: 180, height: 36)

    var body: some View {
        GeometryReader { geo in
            if store.isVisible {
                bubble
                    .background {
                        GeometryReader { inner in
                            Color.clear.preference(key: HintBubbleSizeKey.self, value: inner.size)
                        }
                    }
                    .onPreferenceChange(HintBubbleSizeKey.self) { bubbleSize = $0 }
                    .offset(origin(in: geo.size))
                    .transition(
                        .opacity.combined(with: .scale(scale: 0.96, anchor: .top))
                    )
            }
        }
        .allowsHitTesting(false)
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 5) {
            store.title
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(white: 0.18))
                .lineLimit(2)
                .fixedSize(horizontal: true, vertical: true)
            if store.showDetail, let hint = store.hint {
                hint
                    .font(.caption.weight(.light))
                    .foregroundStyle(Color(white: 0.32))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 240, alignment: .leading)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.97), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 10, y: 3)
    }

    private func origin(in container: CGSize) -> CGSize {
        HoverHintLayout.origin(
            anchor: store.anchor,
            bubble: bubbleSize,
            container: container,
            preferred: store.preferredPlacement
        )
    }
}

enum HoverHintLayout {
    static func origin(
        anchor: CGRect,
        bubble: CGSize,
        container: CGSize,
        preferred: HoverHintPlacement
    ) -> CGSize {
        let margin: CGFloat = 8
        let width = max(bubble.width, 1)
        let height = max(bubble.height, 1)
        var x = anchor.midX - width / 2
        x = min(max(margin, x), max(margin, container.width - width - margin))

        let below = anchor.maxY + margin
        let above = anchor.minY - margin - height
        var place = preferred
        if place == .below, below + height > container.height - margin {
            place = .above
        }
        if place == .above, above < margin {
            place = .below
        }
        let y: CGFloat
        switch place {
        case .below:
            y = min(below, max(margin, container.height - height - margin))
        case .above:
            y = max(margin, above)
        }
        return CGSize(width: x, height: y)
    }
}

private struct HintBubbleSizeKey: PreferenceKey {
    static var defaultValue: CGSize { .zero }
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

extension View {
    func hoverHint(
        _ title: LocalizedStringKey,
        hint: LocalizedStringKey? = nil,
        placement: HoverHintPlacement = .below
    ) -> some View {
        modifier(HoverHintModifier(
            title: Text(title),
            hint: hint.map { Text($0) },
            placement: placement
        ))
    }

    func hoverHint(
        verbatim title: String,
        hint: String? = nil,
        placement: HoverHintPlacement = .below
    ) -> some View {
        modifier(HoverHintModifier(
            title: Text(title),
            hint: hint.map { Text($0) },
            placement: placement
        ))
    }

    func hoverHintHost() -> some View {
        coordinateSpace(name: HoverHintStore.space)
            .overlay { HoverHintCanvas() }
    }
}
