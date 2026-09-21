import SwiftUI

struct ProjectWorkspaceView: View {
    @Environment(ProjectSession.self) private var session
    @Environment(AppLanguageStore.self) private var languageStore
    var onClose: () -> Void

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                board
                AppStatusBar(items: workspaceStatusItems) {
                    if session.mode == .delivery || session.showsFolderReview {
                        ThumbnailSizeControls()
                    }
                }
            }
            .allowsHitTesting(session.mode != .triage)

            if session.mode == .triage {
                TriageView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle(session.project.metadata.displayName)
        .toolbar(session.mode == .triage ? .hidden : .automatic)
        .toolbar { workspaceToolbar }
        .alert(
            Text("error.generic"),
            isPresented: Binding(
                get: { session.failure != nil && session.mode != .triage },
                set: { if !$0 { session.clearFailure() } }
            )
        ) {
            Button("common.ok", role: .cancel) { session.clearFailure() }
        } message: {
            Text(session.failure?.message ?? "")
        }
        .overlay(alignment: .bottom) {
            if session.mode == .triage, let failure = session.failure {
                Text(failure.message)
                    .padding(8)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, 40)
            }
        }
        .onDisappear { session.close() }
    }

    @ToolbarContentBuilder
    private var workspaceToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button(action: onClose) {
                Label("workspace.home", systemImage: "chevron.backward")
            }
            .help(Text("workspace.home.hint"))
        }
        ToolbarItemGroup {
            Button {
                Task { await session.pickAndImport(locale: languageStore.locale) }
            } label: {
                Label("workspace.add_photos", systemImage: "photo.badge.plus")
            }
            .disabled(session.isImporting)
            .help(Text("workspace.add_photos.hint"))

            Button {
                FinderReveal.reveal(session.project.url)
            } label: {
                Label("home.recents.reveal", systemImage: "folder")
            }
            .help(Text("home.recents.reveal.hint"))

            Button {
                session.toggleDelivery()
            } label: {
                Label("workspace.delivery", systemImage: "doc.text.image")
                    .symbolVariant(session.mode == .delivery ? .fill : .none)
            }
            .disabled(!session.showsFolderReview && session.mode != .delivery)
            .help(Text("workspace.delivery.hint"))

            if session.pendingCount > 0 {
                Button {
                    session.flipPending(locale: languageStore.locale)
                } label: {
                    Label("workspace.flip_pending", systemImage: "arrow.up.arrow.down")
                }
                .disabled(session.isImporting)
                .help(Text("workspace.flip_pending.hint"))
            }
        }
        if session.pendingCount > 0 {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    session.startTriage()
                } label: {
                    Label("workspace.triage.start.menu", systemImage: "play.fill")
                }
                .help(Text("workspace.triage.start.hint"))
            }
        }
    }

    @ViewBuilder
    private var board: some View {
        if session.mode == .delivery {
            DeliveryBoardView()
        } else if session.showsFolderReview || session.hasTrashItems {
            ReviewGridView()
        } else {
            InboxGridView()
        }
    }

    private var workspaceStatusItems: [AppStatusItem] {
        let locale = languageStore.locale
        var items: [AppStatusItem] = [
            AppStatusItem(icon: "folder", text: session.project.metadata.displayName, tint: .primary)
        ]
        if session.mode == .delivery {
            items.append(AppStatusItem(icon: "doc.text.image", text: String(localized: "status.delivery.mode", locale: locale)))
            items.append(AppStatusItem(
                icon: "checkmark.circle",
                text: String(localized: "status.delivery \(session.placedCount) \(session.classifiedCount)", locale: locale)
            ))
        } else if session.showsFolderReview {
            items.append(AppStatusItem(icon: "square.grid.2x2", text: String(localized: "status.review", locale: locale)))
            items.append(AppStatusItem(
                icon: "checkmark.circle",
                text: String(localized: "status.classified \(session.classifiedCount)", locale: locale)
            ))
            items.append(AppStatusItem(
                icon: "tray",
                text: String(localized: "status.inbox \(session.pendingCount)", locale: locale)
            ))
        } else {
            items.append(AppStatusItem(
                icon: "tray",
                text: String(localized: "status.inbox \(session.pendingCount)", locale: locale)
            ))
            items.append(AppStatusItem(
                icon: "checkmark.circle",
                text: String(localized: "status.classified \(session.classifiedCount)", locale: locale)
            ))
        }
        if session.isImporting, let progress = session.importProgress {
            items.append(AppStatusItem(
                icon: "square.and.arrow.down",
                text: String(localized: "status.importing \(progress.done) \(progress.total)", locale: locale)
            ))
        }
        if !session.undoStack.isEmpty {
            items.append(AppStatusItem(
                icon: "arrow.uturn.backward",
                text: String(localized: "status.undo \(session.undoStack.count)", locale: locale)
            ))
        }
        return items
    }
}

struct ShortcutsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 10) {
                shortcut("1–24 ↵", "shortcuts.slot")
                shortcut("0 ↵ / G ↵", "shortcuts.general")
                shortcut("⌘⌫", "shortcuts.trash")
                shortcut("← →", "shortcuts.nav")
                shortcut("R", "shortcuts.rotate")
                shortcut("F", "shortcuts.flip")
                shortcut("C", "shortcuts.crop")
                shortcut("⌘Z", "shortcuts.undo")
                shortcut("S", "shortcuts.skip")
                shortcut("Esc", "shortcuts.esc")
                Spacer()
            }
            .padding(24)
            .frame(width: 420, height: 384)
            .navigationTitle(Text("shortcuts.title"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
    }

    private func shortcut(_ keys: String, _ label: LocalizedStringKey) -> some View {
        HStack {
            Text(keys)
                .font(.body.monospaced())
                .frame(width: 120, alignment: .leading)
            Text(label)
            Spacer()
        }
    }
}
