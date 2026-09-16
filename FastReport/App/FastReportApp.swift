import SwiftUI

@main
struct FastReportApp: App {
    @State private var languageStore = AppLanguageStore()
    @State private var mapLibrary = MapLibrary()
    @State private var recents = RecentProjectsStore()
    @State private var imageSettings = ImageSettingsStore()
    @State private var updates = AppUpdateCenter()

    var body: some Scene {
        WindowGroup {
            UpdateOverlayHost {
                HomeView()
            }
            .environment(languageStore)
            .environment(mapLibrary)
            .environment(recents)
            .environment(imageSettings)
            .environment(updates)
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
            }
        }

        Settings {
            SettingsView()
                .environment(languageStore)
                .environment(imageSettings)
                .environment(updates)
                .environment(\.locale, languageStore.locale)
        }
    }
}
