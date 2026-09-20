import AppKit
import SwiftUI

struct MacroPadSpace: View {
    @Environment(KeyboardMacroCenter.self) private var macros
    @Environment(AppLanguageStore.self) private var languageStore

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if !macros.isExpanded {
                DeliveryFloatingOrb(
                    systemImage: "command",
                    help: "macro.expand",
                    hint: "macro.expand.hint",
                    tint: macros.phase == .recording ? .red : .accentColor,
                    isBusy: macros.phase != .idle || macros.capture != .none,
                    offset: macros.padOffset,
                    onExpand: { macros.setExpanded(true) },
                    onOffset: { macros.setPadOffset($0) }
                )
            }
            MacroPadPanelRepresentable(
                isExpanded: macros.isExpanded,
                phase: macros.phase,
                capture: macros.capture,
                chipCount: macros.chips.count,
                locale: languageStore.locale
            )
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .padding(.trailing, 16)
        .padding(.bottom, 52)
        .onAppear {
            macros.refreshTrust()
            macros.setHotkeyEnabled(true)
        }
        .onDisappear {
            macros.setHotkeyEnabled(false)
            macros.setExpanded(false)
            macros.cancelActivity()
        }
    }
}

private struct MacroPadPanelRepresentable: NSViewRepresentable {
    @Environment(KeyboardMacroCenter.self) private var macros
    var isExpanded: Bool
    var phase: MacroPhase
    var capture: MacroCapture
    var chipCount: Int
    var locale: Locale

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        context.coordinator.attach(macros: macros, locale: locale)
        return NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.update(macros: macros, locale: locale)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.tearDown()
    }

    @MainActor
    final class Coordinator {
        private let host = MacroPadPanelHost()
        private weak var macros: KeyboardMacroCenter?

        func attach(macros: KeyboardMacroCenter, locale: Locale) {
            self.macros = macros
            macros.onPadDrag = { [weak host] phase in
                host?.drag(phase)
            }
            host.onMoved = { [weak macros] origin in
                macros?.setPadOrigin(origin)
            }
            host.update(macros: macros, locale: locale)
        }

        func update(macros: KeyboardMacroCenter, locale: Locale) {
            host.update(macros: macros, locale: locale)
        }

        func tearDown() {
            macros?.onPadDrag = nil
            host.hide()
            macros = nil
        }
    }
}

@MainActor
final class MacroPadPanelHost {
    private var panel: NSPanel?
    private var hosting: NSHostingView<AnyView>?
    private var lastExpanded = false
    private var installedLocale: Locale?
    private var isDragging = false
    private var dragMouseStart: CGPoint?
    private var dragFrameStart: CGPoint?

    var onMoved: ((CGPoint) -> Void)?

    func update(macros: KeyboardMacroCenter, locale: Locale) {
        if !macros.isExpanded {
            panel?.orderOut(nil)
            lastExpanded = false
            isDragging = false
            return
        }
        ensurePanel()
        if installedLocale != locale {
            hosting?.rootView = AnyView(
                MacroPadView()
                    .environment(macros)
                    .environment(\.locale, locale)
            )
            installedLocale = locale
        }
        relayout(opening: !lastExpanded, savedOrigin: macros.padOrigin)
        lastExpanded = true
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
        hosting = nil
        installedLocale = nil
        lastExpanded = false
        isDragging = false
    }

    func drag(_ phase: MacroPadDragPhase) {
        guard let panel, panel.isVisible else { return }
        switch phase {
        case .began:
            isDragging = true
            dragMouseStart = NSEvent.mouseLocation
            dragFrameStart = panel.frame.origin
        case .changed:
            guard isDragging, let mouseStart = dragMouseStart, let frameStart = dragFrameStart else { return }
            let mouse = NSEvent.mouseLocation
            panel.setFrameOrigin(
                CGPoint(
                    x: frameStart.x + mouse.x - mouseStart.x,
                    y: frameStart.y + mouse.y - mouseStart.y
                )
            )
        case .ended:
            isDragging = false
            dragMouseStart = nil
            dragFrameStart = nil
            onMoved?(panel.frame.origin)
        }
    }

    private func ensurePanel() {
        guard panel == nil else { return }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 420),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = true
        let hosting = NSHostingView(rootView: AnyView(EmptyView()))
        hosting.sizingOptions = [.intrinsicContentSize]
        panel.contentView = hosting
        self.panel = panel
        self.hosting = hosting
    }

    private func relayout(opening: Bool, savedOrigin: CGPoint) {
        guard let panel, let hosting, !isDragging else { return }
        hosting.invalidateIntrinsicContentSize()
        var size = hosting.fittingSize
        if size.width < 200 { size.width = 380 }
        if size.height < 120 { size.height = 280 }
        var origin = panel.frame.origin
        if opening {
            origin = openingOrigin(size: size, saved: savedOrigin)
        }
        origin = clamp(origin, size: size)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    private func openingOrigin(size: NSSize, saved: CGPoint) -> CGPoint {
        let savedRect = NSRect(origin: saved, size: size)
        if saved != .zero, NSScreen.screens.contains(where: { $0.visibleFrame.insetBy(dx: 12, dy: 12).intersects(savedRect) }) {
            return clamp(saved, size: size)
        }
        let window = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first { window in
            window.isVisible && window.styleMask.contains(.titled)
        }
        let frame = window?.frame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 80, y: 80, width: 900, height: 600)
        return clamp(
            CGPoint(x: frame.maxX - size.width - 20, y: frame.minY + 64),
            size: size
        )
    }

    private func clamp(_ origin: CGPoint, size: NSSize) -> CGPoint {
        let proposed = NSRect(origin: origin, size: size)
        let screen = NSScreen.screens.first { $0.frame.intersects(proposed) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return origin }
        var x = origin.x
        var y = origin.y
        if x + size.width > visible.maxX { x = visible.maxX - size.width - 8 }
        if y + size.height > visible.maxY { y = visible.maxY - size.height - 8 }
        if x < visible.minX { x = visible.minX + 8 }
        if y < visible.minY { y = visible.minY + 8 }
        return CGPoint(x: x, y: y)
    }
}
