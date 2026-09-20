import SwiftUI

struct HomeView: View {
    @Environment(AppLanguageStore.self) private var languageStore
    @Environment(MapLibrary.self) private var mapLibrary
    @Environment(RecentProjectsStore.self) private var recents
    @Environment(ImageSettingsStore.self) private var imageSettings
    @Environment(KeyboardMacroCenter.self) private var macros
    @Environment(ThumbnailSizeStore.self) private var thumbnailSize
    @State private var isWizardPresented = false
    @State private var showShortcuts = false
    @State private var revealFailure: AppFailure?
    @State private var session: ProjectSession?
    @State private var projectPendingRemoval: RecentProject?
    @State private var commandFocus = AppCommandFocus()

    var body: some View {
        VStack(spacing: 0) {
            NavigationStack {
                Group {
                    if let session {
                        ProjectWorkspaceView(onClose: closeProject)
                            .environment(session)
                    } else {
                        homeContent
                    }
                }
            }
            if session == nil {
                AppStatusBar(items: homeStatusItems)
            }
        }
        .sheet(isPresented: $isWizardPresented) {
            ProjectWizardView(maps: mapLibrary.maps) { created in
                openCreated(created)
            }
            .environment(languageStore)
            .environment(recents)
            .environment(\.locale, languageStore.locale)
        }
        .sheet(isPresented: $showShortcuts) {
            ShortcutsSheet()
                .environment(\.locale, languageStore.locale)
        }
        .onAppear {
            loadIfNeeded()
            syncCommandFocus()
        }
        .alert(
            Text("error.generic"),
            isPresented: Binding(
                get: { revealFailure != nil },
                set: { if !$0 { revealFailure = nil } }
            )
        ) {
            Button("common.ok", role: .cancel) { revealFailure = nil }
        } message: {
            Text(revealFailure?.message ?? "")
        }
        .confirmationDialog(
            Text("home.recents.remove.title"),
            isPresented: Binding(
                get: { projectPendingRemoval != nil },
                set: { if !$0 { projectPendingRemoval = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("home.recents.remove.listing") {
                if let project = projectPendingRemoval {
                    recents.removeFromListing(project)
                }
                projectPendingRemoval = nil
            }
            Button("home.recents.remove.files", role: .destructive) {
                if let project = projectPendingRemoval {
                    recents.deleteProjectDirectory(project, locale: languageStore.locale)
                    if recents.lastFailure == nil {
                        macros.removeMacros(forProjectPath: project.path)
                    } else {
                        revealFailure = recents.lastFailure
                    }
                }
                projectPendingRemoval = nil
            }
            Button("common.cancel", role: .cancel) {
                projectPendingRemoval = nil
            }
        } message: {
            Text("home.recents.remove.body \(projectPendingRemoval?.displayName ?? "")")
        }
        .focusedSceneValue(\.appCommands, commandFocus)
        .onChange(of: session?.project.metadata.displayName) { _, _ in
            syncCommandFocus()
        }
        .onChange(of: session?.mode) { _, _ in
            syncCommandFocus()
        }
        .onChange(of: session?.pendingCount) { _, _ in
            syncCommandFocus()
        }
        .onChange(of: session?.undoStack.count) { _, _ in
            syncCommandFocus()
        }
        .onChange(of: languageStore.language) { _, _ in
            mapLibrary.loadBundled(locale: languageStore.locale)
            syncCommandFocus()
        }
    }

    private func syncCommandFocus() {
        commandFocus.session = session
        commandFocus.mapsEmpty = mapLibrary.maps.isEmpty
        commandFocus.locale = languageStore.locale
        commandFocus.thumbnailSize = thumbnailSize
        commandFocus.presentWizard = { isWizardPresented = true }
        commandFocus.openFolder = { openPickedProject() }
        commandFocus.closeProject = { closeProject() }
        commandFocus.presentShortcuts = { showShortcuts = true }
    }

    private var homeContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            organizeCard
            mapsStatus
            Spacer(minLength: 0)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle(Text("home.projects"))
        .toolbar {
            ToolbarItem(placement: .automatic) {
                UpdateToolbarButton()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("home.subtitle")
                .foregroundStyle(.secondary)
            Text("status.version \(AppVersion.display())")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .combine)
    }

    private var organizeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("home.organize.title", systemImage: "square.grid.2x2")
                        .font(.title3.weight(.semibold))
                    Text("home.organize.subtitle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                HStack(spacing: 8) {
                    Button {
                        isWizardPresented = true
                    } label: {
                        Label("home.organize.action", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(mapLibrary.maps.isEmpty)
                    .help(Text(mapLibrary.maps.isEmpty ? "home.organize.disabled" : "home.organize.action.hint"))
                    Button {
                        openPickedProject()
                    } label: {
                        Label("home.organize.open", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                    .help(Text("home.organize.open.help"))
                }
            }
            if !recents.items.isEmpty {
                recentsTable
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.separator.opacity(0.6), lineWidth: 1)
        }
    }

    private var recentsTable: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("home.recents.title")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
            VStack(spacing: 0) {
                ForEach(Array(recents.items.enumerated()), id: \.element.id) { index, project in
                    if index > 0 {
                        Divider().opacity(0.6)
                    }
                    recentsRow(project)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.03))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(.separator.opacity(0.4), lineWidth: 1)
            }
        }
        .padding(.top, 4)
    }

    private func recentsRow(_ project: RecentProject) -> some View {
        HStack(spacing: 8) {
            Button {
                openRecent(project)
            } label: {
                HStack(spacing: 10) {
                    Text(project.displayName)
                        .font(.caption)
                        .lineLimit(1)
                        .frame(width: 132, alignment: .leading)
                    Text(abbreviatedPath(project.path))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(Text("home.recents.open.hint"))
            .accessibilityLabel(Text("home.recents.open"))
            Button {
                reveal(project)
            } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(.borderless)
            .help(Text("home.recents.reveal.hint"))
            .accessibilityLabel(Text("home.recents.reveal"))
            Button {
                projectPendingRemoval = project
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.red)
            .help(Text("home.recents.remove.hint"))
            .accessibilityLabel(Text("home.recents.remove"))
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var mapsStatus: some View {
        switch mapLibrary.state {
        case .idle:
            ProgressView("home.maps.loading")
                .frame(maxWidth: .infinity, alignment: .leading)
        case let .loaded(maps, warnings):
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text("home.maps.available \(maps.count)")
                } icon: {
                    Image(systemName: "checkmark.circle")
                }
                .foregroundStyle(.secondary)

                if let map = maps.first {
                    Text(map.name.resolved(language: languageStore.language))
                        .font(.callout)
                }

                if !warnings.isEmpty {
                    Text("home.warnings.title \(warnings.count)")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
            }
        case let .failed(failure):
            VStack(alignment: .leading, spacing: 10) {
                    Label(failure.message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(failure.debugDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Button("common.retry", systemImage: "arrow.clockwise", action: loadIfNeeded)
                    .help(Text("common.retry.hint"))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func abbreviatedPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    private func reveal(_ project: RecentProject) {
        if let url = recents.resolvedURL(for: project, locale: languageStore.locale) {
            FinderReveal.reveal(url)
        } else {
            revealFailure = recents.lastFailure ?? AppFailure(
                code: "project.bookmark.resolve",
                message: String(localized: "error.project.bookmark.resolve", locale: languageStore.locale)
            )
        }
    }

    private func openRecent(_ project: RecentProject) {
        guard let url = recents.resolvedURL(for: project, locale: languageStore.locale) else {
            revealFailure = recents.lastFailure
            return
        }
        openURL(url, bookmark: project.bookmarkData)
    }

    private func openPickedProject() {
        guard let url = DirectoryPicker.pickProjectDirectory(locale: languageStore.locale) else { return }
        let bookmark = try? SecurityScopedBookmarkStore().save(projectURL: url)
        openURL(url, bookmark: bookmark)
    }

    private func openCreated(_ created: CreatedProject) {
        openURL(created.url, bookmark: created.bookmarkData)
    }

    private func openURL(_ url: URL, bookmark: Data?) {
        do {
            var opened = try ProjectOpener.open(url: url, maps: mapLibrary.maps)
            opened.bookmarkData = bookmark ?? (try? SecurityScopedBookmarkStore().save(projectURL: url))
            recents.remember(opened)
            macros.attach(projectPath: opened.url.path, displayName: opened.metadata.displayName)
            session = ProjectSession(project: opened, settings: imageSettings.settings)
        } catch {
            revealFailure = AppFailure(error, locale: languageStore.locale)
        }
    }

    private func closeProject() {
        macros.detach()
        session?.close()
        session = nil
    }

    private func loadIfNeeded() {
        mapLibrary.loadBundled(locale: languageStore.locale)
    }

    private var homeStatusItems: [AppStatusItem] {
        var items: [AppStatusItem] = [
            AppStatusItem(icon: "house", text: String(localized: "status.home", locale: languageStore.locale))
        ]
        switch mapLibrary.state {
        case let .loaded(maps, _):
            items.append(AppStatusItem(
                icon: "map",
                text: String(localized: "status.maps \(maps.count)", locale: languageStore.locale)
            ))
        case .failed:
            items.append(AppStatusItem(
                icon: "exclamationmark.triangle",
                text: String(localized: "error.maps.unreadable", locale: languageStore.locale),
                tint: .orange
            ))
        default:
            break
        }
        items.append(AppStatusItem(
            icon: "clock",
            text: String(localized: "status.recents \(recents.items.count)", locale: languageStore.locale)
        ))
        items.append(AppStatusItem(
            icon: "info.circle",
            text: String(localized: "status.version \(AppVersion.display())", locale: languageStore.locale)
        ))
        return items
    }
}
