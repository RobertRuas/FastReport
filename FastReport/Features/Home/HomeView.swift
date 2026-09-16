import SwiftUI

struct HomeView: View {
    @Environment(AppLanguageStore.self) private var languageStore
    @Environment(MapLibrary.self) private var mapLibrary
    @Environment(RecentProjectsStore.self) private var recents
    @Environment(ImageSettingsStore.self) private var imageSettings
    @State private var isWizardPresented = false
    @State private var revealFailure: AppFailure?
    @State private var session: ProjectSession?

    var body: some View {
        Group {
            if let session {
                ProjectWorkspaceView(onClose: closeProject)
                    .environment(session)
            } else {
                homeContent
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
        .onAppear(perform: loadIfNeeded)
        .onChange(of: languageStore.language) { _, _ in
            mapLibrary.loadBundled(locale: languageStore.locale)
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
    }

    private var homeContent: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                header
                organizeCard
                mapsStatus
                recentsSection
                Spacer(minLength: 0)
            }
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .navigationTitle(Text("home.title"))
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    SettingsGearButton()
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("home.title")
                .font(.largeTitle.weight(.semibold))
            Text("home.subtitle")
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var organizeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("home.organize.title", systemImage: "square.grid.2x2")
                .font(.title3.weight(.semibold))
            Text("home.organize.subtitle")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("home.organize.action") {
                isWizardPresented = true
            }
            .buttonStyle(.borderedProminent)
            .disabled(mapLibrary.maps.isEmpty)
            .help(mapLibrary.maps.isEmpty ? "home.organize.disabled" : "home.organize.action")
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.separator.opacity(0.6), lineWidth: 1)
        }
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
                Label(failure.message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(failure.debugDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Button("common.retry", action: loadIfNeeded)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    @ViewBuilder
    private var recentsSection: some View {
        if !recents.items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("home.recents.title")
                    .font(.headline)
                ForEach(recents.items) { project in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(project.displayName)
                            Text(abbreviatedPath(project.path))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button("home.recents.open") {
                            openRecent(project)
                        }
                        .buttonStyle(.borderedProminent)
                        Button("home.recents.reveal") {
                            reveal(project)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
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

    private func openCreated(_ created: CreatedProject) {
        openURL(created.url, bookmark: created.bookmarkData)
    }

    private func openURL(_ url: URL, bookmark: Data?) {
        do {
            var opened = try ProjectOpener.open(url: url, maps: mapLibrary.maps)
            opened.bookmarkData = bookmark
            session = ProjectSession(project: opened, settings: imageSettings.settings)
        } catch {
            revealFailure = AppFailure(error, locale: languageStore.locale)
        }
    }

    private func closeProject() {
        session?.close()
        session = nil
    }

    private func loadIfNeeded() {
        mapLibrary.loadBundled(locale: languageStore.locale)
    }
}
