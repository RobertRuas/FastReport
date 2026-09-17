import SwiftUI

struct ProjectWorkspaceView: View {
    @Environment(ProjectSession.self) private var session
    @Environment(AppLanguageStore.self) private var languageStore
    var onClose: () -> Void
    @State private var showShortcuts = false

    var body: some View {
        VStack(spacing: 0) {
            if session.mode != .triage {
                workspaceHeader
                Divider()
            }
            if session.mode == .triage {
                TriageView()
            } else if session.showsFolderReview {
                ReviewGridView()
            } else {
                InboxGridView()
            }
            AppStatusBar(items: workspaceStatusItems)
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
        .onDisappear { session.close() }
    }

    private var workspaceHeader: some View {
        HStack(spacing: 8) {
            IconActionButton(systemImage: "house", help: "workspace.home", action: onClose)
            Text(session.project.metadata.displayName)
                .font(.headline)
            Spacer()
            IconActionButton(
                systemImage: "photo.badge.plus",
                help: "workspace.add_photos",
                isDisabled: session.isImporting
            ) {
                Task { await session.pickAndImport(locale: languageStore.locale) }
            }
            IconActionButton(systemImage: "arrow.up.right.square", help: "home.recents.reveal") {
                FinderReveal.reveal(session.project.url)
            }
            if session.pendingCount > 0 {
                IconActionButton(
                    systemImage: "play.fill",
                    help: "workspace.triage.start \(session.pendingCount)",
                    filled: true,
                    badge: session.pendingCount
                ) {
                    session.startTriage()
                }
            }
            IconActionButton(systemImage: "keyboard", help: "shortcuts.title") {
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
        if session.mode == .triage {
            items.append(AppStatusItem(icon: "keyboard", text: String(localized: "status.triage", locale: locale)))
            items.append(AppStatusItem(
                text: String(localized: "triage.position \(session.triageIndex + 1) \(session.triagePhotos.count)", locale: locale)
            ))
            if !session.currentSlotLabel.isEmpty {
                items.append(AppStatusItem(
                    icon: "tag",
                    text: String(localized: "status.slot \(session.currentSlotLabel)", locale: locale)
                ))
            }
            if !session.buffer.preview.isEmpty {
                items.append(AppStatusItem(text: session.buffer.preview, tint: .orange))
            }
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
            shortcut("⌘Z", "shortcuts.undo")
            shortcut("S", "shortcuts.skip")
            shortcut("Esc", "shortcuts.esc")
            Spacer()
        }
        .padding(24)
        .frame(width: 420, height: 340)
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