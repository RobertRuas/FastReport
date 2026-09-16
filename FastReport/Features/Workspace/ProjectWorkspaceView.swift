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
                    .padding(.bottom, 16)
            }
        }
        .sheet(isPresented: $showShortcuts) {
            ShortcutsSheet()
                .environment(\.locale, languageStore.locale)
        }
        .onDisappear { session.close() }
    }

    private var workspaceHeader: some View {
        HStack(spacing: 12) {
            Button("workspace.home", action: onClose)
            Text(session.project.metadata.displayName)
                .font(.headline)
            Spacer()
            Button("workspace.add_photos") {
                Task { await session.pickAndImport(locale: languageStore.locale) }
            }
            .disabled(session.isImporting)
            Button("home.recents.reveal") {
                FinderReveal.reveal(session.project.url)
            }
            if session.pendingCount > 0 {
                Button("workspace.triage.start \(session.pendingCount)") {
                    session.startTriage()
                }
                .buttonStyle(.borderedProminent)
            }
            Button {
                showShortcuts = true
            } label: {
                Image(systemName: "keyboard")
            }
            .help(Text("shortcuts.title"))
            SettingsGearButton()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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