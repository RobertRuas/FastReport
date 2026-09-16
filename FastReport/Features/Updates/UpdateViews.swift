import SwiftUI

struct SettingsGearButton: View {
    @Environment(AppUpdateCenter.self) private var updates

    var body: some View {
        SettingsLink {
            Label {
                Text("settings.title")
            } icon: {
                Image(systemName: "gearshape")
                    .overlay(alignment: .topTrailing) {
                        if updates.hasUpdateBadge {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 8, height: 8)
                                .offset(x: 3, y: -3)
                                .accessibilityLabel(Text("updates.banner.title"))
                        }
                    }
            }
        }
        .help(Text("settings.title"))
    }
}

struct UpdateBannerView: View {
    @Environment(AppUpdateCenter.self) private var updates
    @Environment(AppLanguageStore.self) private var languageStore

    var body: some View {
        if updates.showsBanner, !updates.showsProgressOverlay, let info = updates.available {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "arrow.down.app")
                VStack(alignment: .leading, spacing: 2) {
                    Text("updates.banner.title")
                        .font(.headline)
                    Text(bannerBody(info))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if updates.phase == .available || updates.phase == .readyToInstall {
                    Button("settings.updates.later", action: updates.dismissBanner)
                    Button(updates.phase == .readyToInstall ? "settings.updates.relaunch" : "settings.updates.install") {
                        updates.beginInstall()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.orange.opacity(0.45), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
            .accessibilityElement(children: .contain)
        }
    }

    private func bannerBody(_ info: AvailableUpdateInfo) -> String {
        let version = info.version
        if let date = info.publishedAt {
            let formatted = date.formatted(
                .dateTime.day().month().year().hour().minute()
                    .locale(languageStore.locale)
            )
            return String(localized: "updates.banner.body \(version) \(formatted)", locale: languageStore.locale)
        }
        return String(localized: "settings.updates.available \(version)", locale: languageStore.locale)
    }
}

struct UpdateProgressCard: View {
    @Environment(AppUpdateCenter.self) private var updates
    @Environment(AppLanguageStore.self) private var languageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(progressTitle)
                .font(.headline)
            if let info = updates.available {
                Text("settings.updates.available \(info.version)")
                if let date = info.publishedAt {
                    Text(publishedText(date))
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
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
            HStack {
                if updates.phase == .checking || updates.phase == .downloading {
                    Button("settings.updates.cancel", action: updates.cancelCurrent)
                }
                Spacer()
                if updates.phase == .readyToInstall {
                    Button("settings.updates.relaunch", action: updates.beginInstall)
                        .buttonStyle(.borderedProminent)
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
            .overlay(alignment: .top) {
                UpdateBannerView()
                    .padding(.top, 12)
                    .padding(.horizontal, 16)
            }
            .overlay {
                if updates.showsProgressOverlay && updates.phase != .checking {
                    Color.black.opacity(0.12)
                        .ignoresSafeArea()
                    UpdateProgressCard()
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
