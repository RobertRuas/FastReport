import AppKit
import SwiftUI

struct TriageView: View {
    @Environment(ProjectSession.self) private var session
    @Environment(AppLanguageStore.self) private var languageStore
    @FocusState private var focused: Bool
    @State private var isCropping = false
    @State private var cropNormalized = PhotoCropGeometry.initial

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            photoStage
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .focusable()
        .focused($focused)
        .onAppear { focused = true }
        .onChange(of: session.currentTriagePhoto?.id) { _, _ in
            cancelCrop()
        }
        .onChange(of: session.cropRequest) { _, _ in
            beginCrop()
        }
        .onKeyPress(action: handleKey)
    }

    private var toolbar: some View {
        HStack(spacing: 14) {
            Button {
                if isCropping {
                    cancelCrop()
                } else {
                    session.exitTriage()
                }
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 28, height: 28)
            }
            .help(Text(isCropping ? "triage.crop.cancel.hint" : "triage.close.hint"))
            .accessibilityLabel(Text(isCropping ? "triage.crop.cancel" : "triage.close"))

            Text(session.currentSlotLabel)
                .foregroundStyle(.white)
                .frame(minWidth: 72, alignment: .leading)

            Text(session.buffer.preview)
                .font(.body.monospacedDigit().weight(.semibold))
                .foregroundStyle(.yellow)
                .frame(minWidth: 48, alignment: .leading)

            Text("triage.position \(session.triageIndex + 1) \(session.triagePhotos.count)")
                .font(.body.monospacedDigit())
                .foregroundStyle(.white.opacity(0.9))

            Spacer()

            if isCropping {
                Button {
                    applyCrop()
                } label: {
                    Image(systemName: "checkmark")
                }
                .help(Text("triage.crop.apply.hint"))
                .accessibilityLabel(Text("triage.crop.apply"))
            } else {
                Button {
                    session.rotateCurrent(locale: languageStore.locale)
                } label: {
                    Image(systemName: "rotate.right")
                }
                .help(Text("triage.rotate.hint"))
                .accessibilityLabel(Text("triage.rotate"))

                Button {
                    session.flipCurrent(locale: languageStore.locale)
                } label: {
                    Image(systemName: "flip.horizontal")
                }
                .help(Text("triage.flip.hint"))
                .accessibilityLabel(Text("triage.flip"))

                Button {
                    beginCrop()
                } label: {
                    Image(systemName: "crop")
                }
                .help(Text("triage.crop.hint"))
                .accessibilityLabel(Text("triage.crop"))

                Button {
                    session.trashCurrent(locale: languageStore.locale)
                } label: {
                    Image(systemName: "trash")
                }
                .help(Text("triage.trash.hint"))
                .accessibilityLabel(Text("triage.trash"))

                Button {
                    session.undoLast(locale: languageStore.locale)
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .help(Text("triage.undo.hint"))
                .accessibilityLabel(Text("triage.undo"))

                Button {
                    session.revealCurrent()
                } label: {
                    Image(systemName: "folder")
                }
                .help(Text("home.recents.reveal.hint"))
                .accessibilityLabel(Text("home.recents.reveal"))
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.black.opacity(0.85))
    }

    private var photoStage: some View {
        GeometryReader { geo in
            ZStack {
                if let photo = session.currentTriagePhoto, let image = loadImage(photo.url) {
                    let padded = CGRect(x: 12, y: 12, width: max(geo.size.width - 24, 1), height: max(geo.size.height - 24, 1))
                    let fitted = PhotoCropGeometry.fittedImageRect(imageSize: image.size, in: padded)
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: fitted.width, height: fitted.height)
                        .position(x: fitted.midX, y: fitted.midY)
                        .id("\(photo.id)-\(session.imageRevision)")
                    if isCropping {
                        PhotoCropOverlay(imageFrame: fitted, crop: $cropNormalized)
                    }
                } else {
                    Text("triage.empty")
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadImage(_ url: URL) -> NSImage? {
        _ = session.imageRevision
        guard let data = try? Data(contentsOf: url, options: [.uncached]) else { return nil }
        return NSImage(data: data)
    }

    private func beginCrop() {
        cropNormalized = PhotoCropGeometry.initial
        isCropping = true
        session.clearBuffer()
    }

    private func cancelCrop() {
        isCropping = false
        cropNormalized = PhotoCropGeometry.initial
    }

    private func applyCrop() {
        session.cropCurrent(normalized: cropNormalized, locale: languageStore.locale)
        cancelCrop()
    }

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        if isCropping {
            if press.key == .escape {
                cancelCrop()
                return .handled
            }
            if press.key == .return {
                applyCrop()
                return .handled
            }
            return .handled
        }
        if press.key == .escape {
            if session.buffer.preview.isEmpty {
                session.exitTriage()
            } else {
                session.clearBuffer()
            }
            return .handled
        }
        if press.key == .return {
            session.commitBuffer(locale: languageStore.locale)
            return .handled
        }
        if press.key == .leftArrow {
            session.goPrevious()
            return .handled
        }
        if press.key == .rightArrow {
            session.goNext()
            return .handled
        }
        if press.modifiers.contains(.command), press.key == .delete {
            session.trashCurrent(locale: languageStore.locale)
            return .handled
        }
        if press.modifiers.contains(.command), press.characters.lowercased() == "z" {
            session.undoLast(locale: languageStore.locale)
            return .handled
        }
        if press.characters.lowercased() == "r", !press.modifiers.contains(.command) {
            session.rotateCurrent(locale: languageStore.locale)
            return .handled
        }
        if press.characters.lowercased() == "f", !press.modifiers.contains(.command) {
            session.flipCurrent(locale: languageStore.locale)
            return .handled
        }
        if press.characters.lowercased() == "c", !press.modifiers.contains(.command) {
            beginCrop()
            return .handled
        }
        if press.characters.lowercased() == "s" {
            session.skipCurrent()
            return .handled
        }
        if let character = press.characters.first {
            session.handleKey(character)
            return .handled
        }
        return .ignored
    }
}
