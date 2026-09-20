import SwiftUI

struct UpdateToolbarButton: View {
    @Environment(AppUpdateCenter.self) private var updates

    var body: some View {
        if updates.showsToolbarUpdateIcon {
            Button {
                updates.presentUpdateSheet()
            } label: {
                Label(
                    updates.isUpdateInProgress ? "updates.toolbar.progress" : "updates.toolbar.available",
                    systemImage: updates.isUpdateInProgress ? "arrow.triangle.2.circlepath" : "arrow.down.app"
                )
            }
            .help(Text(updates.isUpdateInProgress ? "updates.toolbar.progress.hint" : "updates.toolbar.available.hint"))
        }
    }
}

struct UpdateProgressCard: View {
    @Environment(AppUpdateCenter.self) private var updates
    @Environment(AppLanguageStore.self) private var languageStore
    var showsClose: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(progressTitle)
                    .font(.headline)
                Spacer(minLength: 8)
                if showsClose {
                    Button(action: updates.dismissUpdateSheet) {
                        Image(systemName: "xmark.circle")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(Text("updates.sheet.close.hint"))
                    .accessibilityLabel(Text("updates.sheet.close"))
                }
            }
            if updates.phase == .installed {
                Text(updates.statusMessage)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Spacer()
                    Button("common.ok", action: updates.dismissInstalledNotice)
                        .keyboardShortcut(.defaultAction)
                }
            } else if let info = updates.available {
                Text("settings.updates.available \(info.version)")
                if let date = info.publishedAt {
                    Text(publishedText(date))
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                if !info.releaseNotes.isEmpty {
                    Text(info.releaseNotes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxHeight: 120, alignment: .top)
                }
            } else if !updates.statusMessage.isEmpty {
                Text(updates.statusMessage)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if updates.phase != .installed && updates.showsProgressDetails {
                if updates.isProgressDeterminate {
                    ProgressView(value: updates.overallProgress)
                } else {
                    ProgressView(value: updates.overallProgress)
                        .progressViewStyle(.linear)
                    if updates.phase == .checking || updates.phase == .installing {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                if updates.phase == .downloading {
                    Text(byteText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Text("\(Int((updates.overallProgress * 100).rounded()))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: 360)
    }

    private var progressTitle: LocalizedStringKey {
        switch updates.phase {
        case .checking: "settings.updates.progress.checking"
        case .downloading: "settings.updates.progress.download"
        case .extracting: "settings.updates.progress.extract"
        case .readyToInstall: "settings.updates.progress.ready"
        case .installing: "settings.updates.progress.install"
        case .installed: "settings.updates.installed.title"
        case .available: "updates.banner.title"
        default: "settings.updates.check"
        }
    }

    private var byteText: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        let received = formatter.string(fromByteCount: Int64(updates.downloadReceived))
        if updates.downloadExpected > 0 {
            let total = formatter.string(fromByteCount: Int64(updates.downloadExpected))
            return String(localized: "settings.updates.bytes \(received) \(total)", locale: languageStore.locale)
        }
        return received
    }

    private func publishedText(_ date: Date) -> String {
        let formatted = date.formatted(
            .dateTime.day().month().year().hour().minute()
                .locale(languageStore.locale)
        )
        return String(localized: "settings.updates.released \(formatted)", locale: languageStore.locale)
    }
}

struct UpdateOverlayHost<Content: View>: View {
    @Environment(AppUpdateCenter.self) private var updates
    @Environment(\.scenePhase) private var scenePhase
    var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .sheet(isPresented: updateSheetBinding) {
                UpdateProgressCard(showsClose: !updates.isUpdateInProgress)
                    .interactiveDismissDisabled(updates.isUpdateInProgress)
            }
            .onAppear {
                updates.checkInBackground(force: true)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    updates.checkInBackground()
                }
            }
    }

    private var updateSheetBinding: Binding<Bool> {
        Binding(
            get: { updates.showsUpdateSheet },
            set: { presented in
                if !presented, !updates.isUpdateInProgress {
                    updates.dismissUpdateSheet()
                }
            }
        )
    }
}
