import SwiftUI

struct SettingsView: View {
    @Environment(AppLanguageStore.self) private var languageStore
    @Environment(ImageSettingsStore.self) private var imageSettings
    @Environment(KeyboardMacroCenter.self) private var macros
    @Environment(AppUpdateCenter.self) private var updates

    var body: some View {
        Form {
            Section("settings.language") {
                Picker("settings.language", selection: languageBinding) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(LocalizedStringKey(language.displayKey))
                            .tag(language)
                    }
                }
                .pickerStyle(.radioGroup)
                .help(Text("settings.language.help"))
            }

            Section("settings.image") {
                Picker("settings.image.size", selection: maxDimensionBinding) {
                    Text("1024").tag(1024)
                    Text("1600").tag(1600)
                }
                Picker("settings.image.quality", selection: qualityBinding) {
                    Text("settings.image.quality.high").tag(0.85)
                    Text("settings.image.quality.medium").tag(0.7)
                }
            }

            Section("settings.macro") {
                Text("settings.macro.help")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                LabeledContent(
                    "settings.macro.status",
                    value: String(
                        localized: macros.isTrusted ? "settings.macro.trusted" : "settings.macro.untrusted",
                        locale: languageStore.locale
                    )
                )
                LabeledContent("settings.macro.delay") {
                    Stepper(
                        value: delayBinding,
                        in: KeyboardMacroEvent.minStepDelayMs...KeyboardMacroEvent.maxStepDelayMs,
                        step: 50
                    ) {
                        Text(String(localized: "macro.delay.value \(macros.stepDelayMs)", locale: languageStore.locale))
                    }
                }
                .help(Text("macro.delay.hint"))
                if !macros.isTrusted {
                    IconActionButton(
                        systemImage: "lock.open",
                        help: "macro.grant",
                        hint: "macro.grant.hint",
                        title: "macro.grant",
                        filled: true
                    ) {
                        macros.requestTrust()
                    }
                }
            }

            Section("settings.version") {
                LabeledContent("settings.version.marketing", value: AppVersion.display())
                    .textSelection(.enabled)
                if updates.requiresApplicationsFolder {
                    Text("error.updates.location")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    IconActionButton(
                        systemImage: "folder.badge.plus",
                        help: "settings.updates.move.action",
                        hint: "settings.updates.move.action.hint",
                        filled: true
                    ) {
                        updates.moveToApplicationsFolder()
                    }
                }
                IconActionButton(
                    systemImage: "arrow.clockwise",
                    help: "settings.updates.check",
                    hint: "settings.updates.check.hint",
                    title: "settings.updates.check",
                    isDisabled: updates.requiresApplicationsFolder
                ) {
                    updates.checkForUpdatesUserInitiated(presentSheet: true)
                }
                if updates.phase == .checking {
                    ProgressView("settings.updates.checking")
                } else if updates.showsProgressDetails || updates.phase == .installed {
                    UpdateProgressCard()
                } else if !updates.statusMessage.isEmpty {
                    Text(updates.statusMessage)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let info = updates.available, let date = info.publishedAt {
                    Text(publishedText(date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let notes = updates.available?.releaseNotes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("settings.updates.help")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let url = URL(string: "https://github.com/RobertRuas/FastReport/releases") {
                    Link("settings.updates.repo", destination: url)
                        .font(.caption)
                }
            }

            Section("settings.about") {
                Text("settings.about.body")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .frame(minHeight: 420)
        .navigationTitle(Text("settings.title"))
        .padding(.top, 8)
        .onAppear { macros.refreshTrust() }
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { languageStore.language },
            set: { languageStore.setLanguage($0) }
        )
    }

    private var maxDimensionBinding: Binding<Int> {
        Binding(
            get: { imageSettings.settings.maxDimension },
            set: { imageSettings.setMaxDimension($0) }
        )
    }

    private var qualityBinding: Binding<Double> {
        Binding(
            get: { imageSettings.settings.quality },
            set: { imageSettings.setQuality($0) }
        )
    }

    private var delayBinding: Binding<Int> {
        Binding(
            get: { macros.stepDelayMs },
            set: { macros.setStepDelayMs($0) }
        )
    }

    private func publishedText(_ date: Date) -> String {
        let formatted = date.formatted(
            .dateTime.day().month().year().hour().minute()
                .locale(languageStore.locale)
        )
        return String(localized: "settings.updates.released \(formatted)", locale: languageStore.locale)
    }
}
