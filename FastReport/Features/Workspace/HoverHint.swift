import SwiftUI

enum HoverHintPlacement {
    case below
    case above
}

struct HoverHintModifier: ViewModifier {
    var title: Text
    var hint: Text?
    var placement: HoverHintPlacement = .below

    @State private var showTitle = false
    @State private var showHint = false
    @State private var titleTask: Task<Void, Never>?
    @State private var hintTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onHover(perform: handleHover)
            .onDisappear(perform: cancelTasks)
            .overlay {
                if showTitle {
                    bubble
                        .fixedSize()
                        .offset(y: placement == .below ? 28 : -28)
                        .transition(bubbleTransition)
                        .allowsHitTesting(false)
                }
            }
            .zIndex(showTitle ? 80 : 0)
    }

    private var bubbleTransition: AnyTransition {
        let anchor: UnitPoint = placement == .below ? .top : .bottom
        return .asymmetric(
            insertion: .opacity
                .combined(with: .scale(scale: 0.94, anchor: anchor))
                .combined(with: .offset(y: placement == .below ? -6 : 6)),
            removal: .opacity.combined(with: .scale(scale: 0.98, anchor: anchor))
        )
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 5) {
            title
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: true, vertical: true)
            if showHint, let hint {
                hint
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 240, alignment: .leading)
                    .transition(.opacity.combined(with: .move(edge: placement == .below ? .top : .bottom)))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 12, y: 3)
        .animation(.spring(response: 0.36, dampingFraction: 0.84), value: showHint)
    }

    private func handleHover(_ hovering: Bool) {
        cancelTasks()
        guard hovering else {
            withAnimation(.easeOut(duration: 0.14)) {
                showTitle = false
                showHint = false
            }
            return
        }
        titleTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(140))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                showTitle = true
            }
        }
        guard hint != nil else { return }
        hintTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                showHint = true
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
}
