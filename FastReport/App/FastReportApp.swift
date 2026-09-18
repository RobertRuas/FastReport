import SwiftUI

@main
struct FastReportApp: App {
    @State private var languageStore = AppLanguageStore()
    @State private var mapLibrary = MapLibrary()
    @State private var recents = RecentProjectsStore()
    @State private var imageSettings = ImageSettingsStore()
    @State private var thumbnailSize = ThumbnailSizeStore()
    @State private var updates = AppUpdateCenter()
    @State private var hoverHints = HoverHintStore()
    @State private var settingsHints = HoverHintStore()

    var body: some Scene {
        WindowGroup {
            UpdateOverlayHost {
                HomeView()
            }
            .environment(languageStore)
            .environment(mapLibrary)
            .environment(recents)
            .environment(imageSettings)
            .environment(thumbnailSize)
            .environment(updates)
            .environment(hoverHints)
            .environment(\.locale, languageStore.locale)
            .frame(minWidth: 720, minHeight: 500)
        }
        .defaultSize(width: 920, height: 640)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .help) {
                EmptyView()
            }
            CommandGroup(after: .appInfo) {
                Button("settings.updates.check") {
                    updates.checkForUpdatesUserInitiated()
                }
                .keyboardShortcut("u", modifiers: [.command])
                .disabled(updates.requiresApplicationsFolder)
            }
        }

        Settings {
            SettingsView()
                .environment(languageStore)
                .environment(imageSettings)
                .environment(updates)
                .environment(settingsHints)
                .environment(\.locale, languageStore.locale)
                .coordinateSpace(name: HoverHintStore.space)
                .overlay { HoverHintCanvas() }
        }
    }
}
