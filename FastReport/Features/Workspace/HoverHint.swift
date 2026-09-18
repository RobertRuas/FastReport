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
            .overlay(alignment: placement == .below ? .bottom : .top) {
                if showTitle {
                    bubble
                        .offset(y: placement == .below ? 8 : -8)
                        .alignmentGuide(placement == .below ? .bottom : .top) { dimensions in
                            placement == .below ? dimensions[.top] : dimensions[.bottom]
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: placement == .below ? .top : .bottom)))
                        .allowsHitTesting(false)
                }
            }
            .zIndex(showTitle ? 80 : 0)
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 3) {
            title
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
            if showHint, let hint {
                hint
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(minWidth: 36, maxWidth: 220, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.14), radius: 8, y: 2)
    }

    private func handleHover(_ hovering: Bool) {
        cancelTasks()
        guard hovering else {
            showTitle = false
            showHint = false
            return
        }
        titleTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(160))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.12)) {
                showTitle = true
            }
        }
        guard hint != nil else { return }
        hintTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.16)) {
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
