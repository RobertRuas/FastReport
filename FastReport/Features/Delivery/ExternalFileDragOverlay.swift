import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ExternalFileDragOverlay: NSViewRepresentable {
    let url: URL
    let preview: NSImage?
    var isPlaced: Bool
    var markTitle: String
    var unmarkTitle: String
    var onPlaced: () -> Void
    var onToggle: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            url: url,
            preview: preview,
            isPlaced: isPlaced,
            markTitle: markTitle,
            unmarkTitle: unmarkTitle,
            onPlaced: onPlaced,
            onToggle: onToggle
        )
    }

    func makeNSView(context: Context) -> ExternalFileDragView {
        let view = ExternalFileDragView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: ExternalFileDragView, context: Context) {
        context.coordinator.url = url
        context.coordinator.preview = preview
        context.coordinator.isPlaced = isPlaced
        context.coordinator.markTitle = markTitle
        context.coordinator.unmarkTitle = unmarkTitle
        context.coordinator.onPlaced = onPlaced
        context.coordinator.onToggle = onToggle
        nsView.coordinator = context.coordinator
    }

    final class Coordinator {
        var url: URL
        var preview: NSImage?
        var isPlaced: Bool
        var markTitle: String
        var unmarkTitle: String
        var onPlaced: () -> Void
        var onToggle: () -> Void

        init(
            url: URL,
            preview: NSImage?,
            isPlaced: Bool,
            markTitle: String,
            unmarkTitle: String,
            onPlaced: @escaping () -> Void,
            onToggle: @escaping () -> Void
        ) {
            self.url = url
            self.preview = preview
            self.isPlaced = isPlaced
            self.markTitle = markTitle
            self.unmarkTitle = unmarkTitle
            self.onPlaced = onPlaced
            self.onToggle = onToggle
        }
    }
}

final class ExternalFileDragView: NSView, NSDraggingSource {
    weak var coordinator: ExternalFileDragOverlay.Coordinator?
    private var isDragging = false
    private var accessingFile = false

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        isDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !isDragging, let coordinator else { return }
        isDragging = true
        accessingFile = coordinator.url.startAccessingSecurityScopedResource()
        let writer = ReportPhotoPasteboardWriter(url: coordinator.url)
        let item = NSDraggingItem(pasteboardWriter: writer)
        item.setDraggingFrame(bounds, contents: coordinator.preview ?? NSImage(contentsOf: coordinator.url))
        beginDraggingSession(with: [item], event: event, source: self)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        guard let coordinator else { return nil }
        let menu = NSMenu()
        let item = NSMenuItem(
            title: coordinator.isPlaced ? coordinator.unmarkTitle : coordinator.markTitle,
            action: #selector(togglePlacement),
            keyEquivalent: ""
        )
        item.target = self
        menu.addItem(item)
        return menu
    }

    @objc private func togglePlacement() {
        coordinator?.onToggle()
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        context == .outsideApplication ? .copy : []
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        isDragging = false
        if accessingFile {
            coordinator?.url.stopAccessingSecurityScopedResource()
            accessingFile = false
        }
        guard operation.contains(.copy)
            || operation.contains(.generic)
            || operation.contains(.link)
            || operation.contains(.move)
        else { return }
        coordinator?.onPlaced()
    }
}

final class ReportPhotoPasteboardWriter: NSObject, NSPasteboardWriting {
    private let url: URL

    init(url: URL) {
        self.url = url
    }

    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        [
            .fileURL,
            NSPasteboard.PasteboardType("NSFilenamesPboardType"),
            NSPasteboard.PasteboardType(UTType.jpeg.identifier),
            .png
        ]
    }

    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        switch type {
        case .fileURL:
            return url.absoluteURL.absoluteString
        case NSPasteboard.PasteboardType("NSFilenamesPboardType"):
            return [url.path]
        case NSPasteboard.PasteboardType(UTType.jpeg.identifier):
            return try? Data(contentsOf: url)
        case .png:
            guard let image = NSImage(contentsOf: url),
                  let tiff = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff)
            else { return nil }
            return rep.representation(using: .png, properties: [:])
        default:
            return nil
        }
    }
}
