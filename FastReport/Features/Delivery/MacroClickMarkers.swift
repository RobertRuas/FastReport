import AppKit

struct MacroClickMarkerModel: Equatable, Identifiable {
    var id: Int
    var stepNumber: Int
    var cocoaPoint: CGPoint
    var isFocused: Bool
    var isActivePlayback: Bool
}

@MainActor
final class MacroClickMarkerHost {
    var onMove: ((Int, CGPoint, Bool) -> Void)?
    var onSelect: ((Int) -> Void)?

    private var panels: [Int: NSPanel] = [:]

    func sync(_ markers: [MacroClickMarkerModel], visible: Bool) {
        guard visible else {
            closeAll()
            return
        }
        let ids = Set(markers.map(\.id))
        for id in panels.keys where !ids.contains(id) {
            panels[id]?.orderOut(nil)
            panels[id]?.close()
            panels[id] = nil
        }
        for marker in markers {
            let size: CGFloat = marker.isFocused || marker.isActivePlayback ? 48 : 40
            let frame = NSRect(
                x: marker.cocoaPoint.x - size / 2,
                y: marker.cocoaPoint.y - size / 2,
                width: size,
                height: size
            )
            let panel = panels[marker.id] ?? makePanel()
            panels[marker.id] = panel
            let view: MacroClickMarkerView
            if let existing = panel.contentView as? MacroClickMarkerView {
                view = existing
            } else {
                view = MacroClickMarkerView(frame: NSRect(origin: .zero, size: frame.size))
                panel.contentView = view
            }
            view.stepNumber = marker.stepNumber
            view.isFocused = marker.isFocused
            view.isActivePlayback = marker.isActivePlayback
            view.onSelect = { [weak self] in self?.onSelect?(marker.id) }
            view.onDrag = { [weak self] point, ended in
                self?.onMove?(marker.id, point, ended)
            }
            panel.setFrame(frame, display: true)
            if !panel.isVisible {
                panel.orderFrontRegardless()
            }
        }
    }

    func closeAll() {
        for panel in panels.values {
            panel.orderOut(nil)
            panel.close()
        }
        panels.removeAll()
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 40, height: 40),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 3)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = false
        panel.becomesKeyOnlyIfNeeded = true
        return panel
    }
}

final class MacroClickMarkerView: NSView {
    var stepNumber = 1 {
        didSet { needsDisplay = true }
    }
    var isFocused = false {
        didSet { needsDisplay = true }
    }
    var isActivePlayback = false {
        didSet { needsDisplay = true }
    }
    var onDrag: ((CGPoint, Bool) -> Void)?
    var onSelect: (() -> Void)?

    private var dragging = false

    override var isFlipped: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        dragging = false
        onSelect?()
    }

    override func mouseDragged(with event: NSEvent) {
        dragging = true
        moveWindow(to: NSEvent.mouseLocation, ended: false)
    }

    override func mouseUp(with event: NSEvent) {
        if dragging {
            moveWindow(to: NSEvent.mouseLocation, ended: true)
        }
        dragging = false
    }

    override func draw(_ dirtyRect: NSRect) {
        let inset: CGFloat = 3
        let bounds = self.bounds.insetBy(dx: inset, dy: inset)
        let fill = isActivePlayback ? NSColor.systemOrange : NSColor.controlAccentColor
        fill.withAlphaComponent(isFocused || isActivePlayback ? 0.95 : 0.82).setFill()
        NSBezierPath(ovalIn: bounds).fill()
        NSColor.white.withAlphaComponent(0.9).setStroke()
        let ring = NSBezierPath(ovalIn: bounds.insetBy(dx: 0.8, dy: 0.8))
        ring.lineWidth = isFocused ? 2.4 : 1.4
        ring.stroke()

        let label = "\(stepNumber)" as NSString
        let font = NSFont.systemFont(ofSize: bounds.width > 36 ? 15 : 13, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let size = label.size(withAttributes: attributes)
        let origin = NSPoint(
            x: (self.bounds.width - size.width) / 2,
            y: (self.bounds.height - size.height) / 2
        )
        label.draw(at: origin, withAttributes: attributes)
    }

    private func moveWindow(to cocoaPoint: CGPoint, ended: Bool) {
        guard let window else {
            onDrag?(cocoaPoint, ended)
            return
        }
        let size = window.frame.size
        window.setFrameOrigin(NSPoint(x: cocoaPoint.x - size.width / 2, y: cocoaPoint.y - size.height / 2))
        onDrag?(cocoaPoint, ended)
    }
}

@MainActor
final class MacroClickPlacementOverlay {
    private var panels: [NSPanel] = []
    private var onPick: ((CGPoint) -> Void)?
    private var onCancel: (() -> Void)?
    private var keyMonitor: Any?

    func begin(onPick: @escaping (CGPoint) -> Void, onCancel: @escaping () -> Void) {
        end()
        self.onPick = onPick
        self.onCancel = onCancel
        for screen in NSScreen.screens {
            let panel = NSPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.ignoresMouseEvents = false
            let view = MacroClickPlacementView(frame: NSRect(origin: .zero, size: screen.frame.size))
            view.onPick = { [weak self] point in
                self?.finishPick(point)
            }
            panel.contentView = view
            panel.orderFrontRegardless()
            panels.append(panel)
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.cancel()
                return nil
            }
            return event
        }
        NSCursor.crosshair.push()
    }

    func end() {
        if keyMonitor != nil {
            NSCursor.pop()
        }
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        keyMonitor = nil
        for panel in panels {
            panel.orderOut(nil)
            panel.close()
        }
        panels.removeAll()
        onPick = nil
        onCancel = nil
    }

    private func finishPick(_ point: CGPoint) {
        let pick = onPick
        end()
        pick?(point)
    }

    func cancel() {
        let cancel = onCancel
        end()
        cancel?()
    }
}

final class MacroClickPlacementView: NSView {
    var onPick: ((CGPoint) -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseDown(with event: NSEvent) {
        onPick?(NSEvent.mouseLocation)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.08).setFill()
        bounds.fill()
        let text = String(localized: "macro.place.click") as NSString
        let hint = String(localized: "macro.place.hint") as NSString
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        let hintAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.85)
        ]
        let titleSize = text.size(withAttributes: titleAttributes)
        let hintSize = hint.size(withAttributes: hintAttributes)
        let padding: CGFloat = 16
        let box = NSRect(
            x: (bounds.width - max(titleSize.width, hintSize.width) - padding * 2) / 2,
            y: bounds.height - 88,
            width: max(titleSize.width, hintSize.width) + padding * 2,
            height: titleSize.height + hintSize.height + padding * 2
        )
        NSColor.black.withAlphaComponent(0.55).setFill()
        NSBezierPath(roundedRect: box, xRadius: 12, yRadius: 12).fill()
        text.draw(
            at: NSPoint(x: box.midX - titleSize.width / 2, y: box.maxY - padding - titleSize.height),
            withAttributes: titleAttributes
        )
        hint.draw(
            at: NSPoint(x: box.midX - hintSize.width / 2, y: box.minY + padding),
            withAttributes: hintAttributes
        )
    }
}
