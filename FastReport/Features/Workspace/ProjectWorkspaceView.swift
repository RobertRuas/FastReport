import SwiftUI

struct ProjectWorkspaceView: View {
    @Environment(ProjectSession.self) private var session
    @Environment(AppLanguageStore.self) private var languageStore
    var onClose: () -> Void
    @State private var showShortcuts = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                workspaceHeader
                Divider()
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
                    .background(.red.opacity(0.85), in: Capsule())
                    .foregroundStyle(.white)
                    .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showShortcuts) {
            ShortcutsSheet()
                .environment(\.locale, languageStore.locale)
        }
        .overlay(alignment: .bottomTrailing) {
            if session.mode == .delivery {
                MacroPadSpace()
            }
        }
        .onDisappear { session.close() }
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

    private var workspaceHeader: some View {
        HStack(spacing: 8) {
            IconActionButton(systemImage: "house", help: "workspace.home", hint: "workspace.home.hint", action: onClose)
            Text(session.project.metadata.displayName)
                .font(.headline)
            Spacer()
            IconActionButton(
                systemImage: "photo.badge.plus",
                help: "workspace.add_photos",
                hint: "workspace.add_photos.hint",
                isDisabled: session.isImporting
            ) {
                Task { await session.pickAndImport(locale: languageStore.locale) }
            }
            IconActionButton(
                systemImage: "arrow.up.right.square",
                help: "home.recents.reveal",
                hint: "home.recents.reveal.hint"
            ) {
                FinderReveal.reveal(session.project.url)
            }
            IconActionButton(
                systemImage: "doc.text.image",
                help: "workspace.delivery",
                hint: "workspace.delivery.hint",
                filled: session.mode == .delivery,
                isDisabled: !session.showsFolderReview && session.mode != .delivery
            ) {
                session.toggleDelivery()
            }
            if session.pendingCount > 0 {
                IconActionButton(
                    systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right",
                    help: "workspace.flip_pending",
                    hint: "workspace.flip_pending.hint",
                    isDisabled: session.isImporting
                ) {
                    session.flipPending(locale: languageStore.locale)
                }
                IconActionButton(
                    systemImage: "play.fill",
                    help: "workspace.triage.start \(session.pendingCount)",
                    hint: "workspace.triage.start.hint",
                    filled: true,
                    badge: session.pendingCount
                ) {
                    session.startTriage()
                }
            }
            IconActionButton(systemImage: "keyboard", help: "shortcuts.title", hint: "shortcuts.title.hint") {
                showShortcuts = true
            }
            UpdateToolbarButton()
            SettingsGearButton()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("shortcuts.title")
                .font(.headline)
            shortcut("1–24 ↵", "shortcuts.slot")
            shortcut("0 ↵ / G ↵", "shortcuts.general")
            shortcut("⌘⌫", "shortcuts.trash")
            shortcut("← →", "shortcuts.nav")
            shortcut("R", "shortcuts.rotate")
            shortcut("F", "shortcuts.flip")
            shortcut("C", "shortcuts.crop")
            shortcut("⌘Z", "shortcuts.undo")
            shortcut("⌘␣", "shortcuts.macro")
            shortcut("S", "shortcuts.skip")
            shortcut("Esc", "shortcuts.esc")
            Spacer()
        }
        .padding(24)
            .frame(width: 420, height: 408)
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