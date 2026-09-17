import SwiftUI

struct SettingsGearButton: View {
    @State private var hovering = false

    var body: some View {
        SettingsLink {
            Image(systemName: "gearshape")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 30, height: 30)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(hovering ? 0.10 : 0.05))
                }
        }
        .buttonStyle(.plain)
        .labelStyle(.iconOnly)
        .onHover { hovering = $0 }
        .help(Text("settings.title"))
        .accessibilityLabel(Text("settings.title"))
    }
}

struct UpdateToolbarButton: View {
    @Environment(AppUpdateCenter.self) private var updates
    @State private var animating = false

    private let green = Color(red: 0.12, green: 0.68, blue: 0.38)

    var body: some View {
        if updates.showsToolbarUpdateIcon {
            Button(action: updates.presentUpdateSheet) {
                Image(systemName: updates.isUpdateInProgress ? "arrow.triangle.2.circlepath" : "arrow.down.app.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(green)
                    .frame(width: 30, height: 30)
                    .background {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(green.opacity(0.12))
                    }
                    .rotationEffect(.degrees(updates.isUpdateInProgress && animating ? 360 : 0))
                    .scaleEffect(!updates.isUpdateInProgress && animating ? 1.08 : 1)
                    .shadow(color: green.opacity(animating ? 0.55 : 0.18), radius: animating ? 5 : 1)
            }
            .buttonStyle(.plain)
            .help(Text(updates.isUpdateInProgress ? "updates.toolbar.progress" : "updates.toolbar.available"))
            .accessibilityLabel(Text(updates.isUpdateInProgress ? "updates.toolbar.progress" : "updates.toolbar.available"))
            .onAppear(perform: restartMotion)
            .onChange(of: updates.isUpdateInProgress) { _, _ in
                restartMotion()
            }
        }
    }

    private func restartMotion() {
        animating = false
        DispatchQueue.main.async {
            if updates.isUpdateInProgress {
                withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                    animating = true
                }
            } else {
                withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                    animating = true
                }
            }
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
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(Text("updates.sheet.close"))
                    .accessibilityLabel(Text("updates.sheet.close"))
                }
            }
            if updates.phase == .installed {
                Text(updates.statusMessage)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Spacer()
                    IconActionButton(systemImage: "checkmark", help: "common.ok", filled: true, action: updates.dismissInstalledNotice)
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
            HStack {
                if updates.phase == .checking || updates.phase == .downloading {
                    IconActionButton(systemImage: "xmark", help: "settings.updates.cancel", action: updates.cancelCurrent)
                }
                Spacer()
                if updates.phase == .available {
                    IconActionButton(systemImage: "arrow.down.app.fill", help: "settings.updates.install", filled: true) {
                        updates.beginInstall()
                    }
                } else if updates.phase == .readyToInstall {
                    IconActionButton(systemImage: "arrow.clockwise.circle.fill", help: "settings.updates.relaunch", filled: true, action: updates.beginInstall)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: 360)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 12, y: 4)
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
            .overlay {
                if updates.showsUpdateSheet {
                    ZStack {
                        Color.black.opacity(0.18)
                            .ignoresSafeArea()
                            .onTapGesture(perform: updates.dismissUpdateSheet)
                        UpdateProgressCard(showsClose: true)
                    }
                }
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
}
