import AppKit
import SwiftUI

enum HoverHintPlacement {
    case below
    case above
}

struct HoverHintModifier: ViewModifier {
    var title: Text
    var hint: Text?
    var placement: HoverHintPlacement = .below

    @Environment(\.locale) private var locale
    @State private var session = UUID()
    @State private var screenAnchor: CGRect = .zero
    @State private var titleTask: Task<Void, Never>?
    @State private var hintTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .background {
                ScreenAnchorReader { screenAnchor = $0 }
            }
            .onHover { hovering in
                handleHover(hovering)
            }
            .onDisappear {
                cancelTasks()
                HoverHintPanel.shared.hide(session: session)
            }
    }

    private func handleHover(_ hovering: Bool) {
        cancelTasks()
        guard hovering else {
            HoverHintPanel.shared.hide(session: session)
            return
        }
        let current = session
        let anchor = screenAnchor
        titleTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(140))
            guard !Task.isCancelled else { return }
            HoverHintPanel.shared.show(
                session: current,
                title: title,
                hint: hint,
                showDetail: false,
                anchor: anchor,
                placement: placement,
                locale: locale
            )
        }
        guard hint != nil else { return }
        hintTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            HoverHintPanel.shared.show(
                session: current,
                title: title,
                hint: hint,
                showDetail: true,
                anchor: screenAnchor,
                placement: placement,
                locale: locale
            )
        }
    }

    private func cancelTasks() {
        titleTask?.cancel()
        hintTask?.cancel()
        titleTask = nil
        hintTask = nil
    }
}

private struct ScreenAnchorReader: NSViewRepresentable {
    var onChange: (CGRect) -> Void

    func makeNSView(context: Context) -> AnchorView {
        let view = AnchorView()
        view.onChange = onChange
        return view
    }

    func updateNSView(_ nsView: AnchorView, context: Context) {
        nsView.onChange = onChange
        DispatchQueue.main.async {
            nsView.report()
        }
    }

    final class AnchorView: NSView {
        var onChange: ((CGRect) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            report()
        }

        override func layout() {
            super.layout()
            report()
        }

        func report() {
            guard let window, window.occlusionState.contains(.visible), bounds.width > 0, bounds.height > 0 else { return }
            let inWindow = convert(bounds, to: nil)
            onChange?(window.convertToScreen(inWindow))
        }
    }
}

@MainActor
final class HoverHintPanel {
    static let shared = HoverHintPanel()

    private var panel: NSPanel?
    private var session: UUID?

    func show(
        session: UUID,
        title: Text,
        hint: Text?,
        showDetail: Bool,
        anchor: CGRect,
        placement: HoverHintPlacement,
        locale: Locale
    ) {
        guard anchor.width > 0, anchor.height > 0 else { return }
        self.session = session
        let root = HoverHintBubble(title: title, hint: hint, showDetail: showDetail)
            .environment(\.locale, locale)
        let hosting = NSHostingView(rootView: root)
        hosting.sizingOptions = .intrinsicContentSize
        let size = hosting.fittingSize
        guard size.width > 1, size.height > 1 else { return }

        let visible = NSScreen.main?.visibleFrame ?? NSScreen.screens.first?.visibleFrame ?? .zero
        let frame = HoverHintLayout.panelFrame(
            anchor: anchor,
            bubble: size,
            visible: visible,
            preferred: placement
        )

        let panel = existingPanel()
        panel.contentView = hosting
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
    }

    func hide(session: UUID) {
        guard self.session == session || self.session == nil else { return }
        self.session = nil
        panel?.orderOut(nil)
    }

    private func existingPanel() -> NSPanel {
        if let panel {
            return panel
        }
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        self.panel = panel
        return panel
    }
}

private struct HoverHintBubble: View {
    var title: Text
    var hint: Text?
    var showDetail: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            title
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(white: 0.18))
                .lineLimit(2)
                .fixedSize(horizontal: true, vertical: true)
            if showDetail, let hint {
                hint
                    .font(.caption.weight(.light))
                    .foregroundStyle(Color(white: 0.32))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minWidth: 180, idealWidth: 240, maxWidth: 260, alignment: .leading)
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
}

enum HoverHintLayout {
    static func panelFrame(
        anchor: CGRect,
        bubble: CGSize,
        visible: CGRect,
        preferred: HoverHintPlacement
    ) -> CGRect {
        let margin: CGFloat = 8
        let width = max(bubble.width, 1)
        let height = max(bubble.height, 1)
        var x = anchor.midX - width / 2
        let minX = visible.minX + margin
        let maxX = max(minX, visible.maxX - width - margin)
        x = min(max(minX, x), maxX)

        let belowY = anchor.minY - margin - height
        let aboveY = anchor.maxY + margin
        var place = preferred
        if place == .below, belowY < visible.minY + margin {
            place = .above
        }
        if place == .above, aboveY + height > visible.maxY - margin {
            place = .below
        }
        let y: CGFloat
        switch place {
        case .below:
            y = max(visible.minY + margin, belowY)
        case .above:
            y = min(aboveY, visible.maxY - height - margin)
        }
        return CGRect(x: x, y: y, width: width, height: height)
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
