import AppKit
import Foundation
import UniformTypeIdentifiers

enum FinderReveal {
    static func reveal(_ url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

enum DirectoryPicker {
    @MainActor
    static func pickParentDirectory(locale: Locale) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.treatsFilePackagesAsDirectories = true
        panel.message = String(localized: "wizard.location.panel", locale: locale)
        panel.prompt = String(localized: "wizard.location.prompt", locale: locale)
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    @MainActor
    static func pickProjectDirectory(locale: Locale) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.treatsFilePackagesAsDirectories = true
        panel.message = String(localized: "home.organize.open.panel", locale: locale)
        panel.prompt = String(localized: "home.organize.open.prompt", locale: locale)
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    @MainActor
    static func pickImageFiles(locale: Locale) -> [URL] {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.image]
        panel.message = String(localized: "import.panel", locale: locale)
        panel.prompt = String(localized: "import.panel.prompt", locale: locale)
        guard panel.runModal() == .OK else { return [] }
        return panel.urls
    }
}
