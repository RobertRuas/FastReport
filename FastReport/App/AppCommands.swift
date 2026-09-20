import SwiftUI

struct AppCommandFocusKey: FocusedValueKey {
    typealias Value = AppCommandFocus
}

extension FocusedValues {
    var appCommands: AppCommandFocus? {
        get { self[AppCommandFocusKey.self] }
        set { self[AppCommandFocusKey.self] = newValue }
    }
}

@MainActor
final class AppCommandFocus {
    var session: ProjectSession?
    var mapsEmpty = true
    var locale = Locale(identifier: "pt")
    var thumbnailSize: ThumbnailSizeStore?
    var presentWizard: () -> Void = {}
    var openFolder: () -> Void = {}
    var closeProject: () -> Void = {}
    var presentShortcuts: () -> Void = {}
}

struct AppCommands: Commands {
    @FocusedValue(\.appCommands) private var focus

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("home.organize.action") { focus?.presentWizard() }
                .keyboardShortcut("n")
                .disabled(focus?.session != nil || focus?.mapsEmpty != false)
            Button("home.organize.open") { focus?.openFolder() }
                .keyboardShortcut("o")
                .disabled(focus?.session != nil)
        }
        CommandGroup(after: .newItem) {
            Button("menu.file.close_project") { focus?.closeProject() }
                .keyboardShortcut("w", modifiers: [.command, .shift])
                .disabled(focus?.session == nil)
            Button("workspace.add_photos") {
                guard let focus, let session = focus.session else { return }
                Task { await session.pickAndImport(locale: focus.locale) }
            }
            .disabled(focus?.session == nil || focus?.session?.isImporting == true || focus?.session?.mode == .triage)
            Button("home.recents.reveal") {
                if let session = focus?.session {
                    FinderReveal.reveal(session.project.url)
                }
            }
            .disabled(focus?.session == nil)
        }
        CommandGroup(after: .undoRedo) {
            Button("triage.undo") {
                guard let focus, let session = focus.session else { return }
                session.undoLast(locale: focus.locale)
            }
            .disabled(focus?.session == nil || focus?.session?.undoStack.isEmpty == true)
        }
        CommandMenu("menu.view") {
            Button("workspace.delivery") {
                focus?.session?.toggleDelivery()
            }
            .disabled(focus?.session == nil || focus?.session?.mode == .triage || (focus?.session?.showsFolderReview == false && focus?.session?.mode != .delivery))
            Button("workspace.triage.start.menu") {
                focus?.session?.startTriage()
            }
            .disabled(focus?.session == nil || (focus?.session?.pendingCount ?? 0) == 0 || focus?.session?.mode == .triage)
            Button("workspace.flip_pending") {
                guard let focus, let session = focus.session else { return }
                session.flipPending(locale: focus.locale)
            }
            .disabled(focus?.session == nil || (focus?.session?.pendingCount ?? 0) == 0 || focus?.session?.isImporting == true || focus?.session?.mode == .triage)
            Divider()
            Button("review.thumbs.smaller") {
                guard let thumbs = focus?.thumbnailSize else { return }
                thumbs.makeSmaller(currentSize: thumbs.resolvedSize)
            }
            .disabled(focus?.session == nil || focus?.thumbnailSize?.canShrink != true)
            Button("review.thumbs.larger") {
                guard let thumbs = focus?.thumbnailSize else { return }
                thumbs.makeLarger(currentSize: thumbs.resolvedSize)
            }
            .disabled(focus?.session == nil || focus?.thumbnailSize?.canGrow != true)
            Button("review.thumbs.automatic") {
                focus?.thumbnailSize?.useAutomatic()
            }
            .disabled(focus?.session == nil)
        }
        CommandMenu("menu.photo") {
            Button("triage.rotate") {
                guard let focus, let session = focus.session else { return }
                session.rotateCurrent(locale: focus.locale)
            }
            .keyboardShortcut("r")
            .disabled(focus?.session?.mode != .triage)
            Button("triage.flip") {
                guard let focus, let session = focus.session else { return }
                session.flipCurrent(locale: focus.locale)
            }
            .disabled(focus?.session?.mode != .triage)
            Button("triage.crop") {
                focus?.session?.requestCrop()
            }
            .disabled(focus?.session?.mode != .triage)
            Button("triage.trash") {
                guard let focus, let session = focus.session else { return }
                session.trashCurrent(locale: focus.locale)
            }
            .keyboardShortcut(.delete, modifiers: [.command])
            .disabled(focus?.session?.mode != .triage)
            Button("home.recents.reveal") {
                focus?.session?.revealCurrent()
            }
            .disabled(focus?.session?.mode != .triage)
        }
        CommandGroup(after: .help) {
            Button("shortcuts.title") { focus?.presentShortcuts() }
                .disabled(focus?.session == nil)
            if let url = URL(string: "https://github.com/RobertRuas/FastReport/releases") {
                Link("settings.updates.repo", destination: url)
            }
        }
    }
}
