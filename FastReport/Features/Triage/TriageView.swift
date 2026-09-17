import AppKit
import SwiftUI

struct TriageView: View {
    @Environment(ProjectSession.self) private var session
    @Environment(AppLanguageStore.self) private var languageStore
    @FocusState private var focused: Bool

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
        .onKeyPress(action: handleKey)
    }

    private var toolbar: some View {
        HStack(spacing: 14) {
            Button {
                session.exitTriage()
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 28, height: 28)
            }
            .help(Text("triage.close"))

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

            Button {
                session.rotateCurrent(locale: languageStore.locale)
            } label: {
                Image(systemName: "rotate.right")
            }
            .help(Text("triage.rotate"))

            Button {
                session.trashCurrent(locale: languageStore.locale)
            } label: {
                Image(systemName: "trash")
            }
            .help(Text("triage.trash"))

            Button {
                session.undoLast(locale: languageStore.locale)
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .help(Text("triage.undo"))

            Button {
                session.revealCurrent()
            } label: {
                Image(systemName: "folder")
            }
            .help(Text("home.recents.reveal"))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.black.opacity(0.85))
    }

    private var photoStage: some View {
        ZStack {
            if let photo = session.currentTriagePhoto, let image = loadImage(photo.url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(12)
                    .id("\(photo.id)-\(session.imageRevision)")
            } else {
                Text("triage.empty")
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadImage(_ url: URL) -> NSImage? {
        _ = session.imageRevision
        guard let data = try? Data(contentsOf: url, options: [.uncached]) else { return nil }
        return NSImage(data: data)
    }

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
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
