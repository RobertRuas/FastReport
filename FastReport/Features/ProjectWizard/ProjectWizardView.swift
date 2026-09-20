import SwiftUI

struct ProjectWizardView: View {
    @Environment(AppLanguageStore.self) private var languageStore
    @Environment(RecentProjectsStore.self) private var recents
    @Environment(\.dismiss) private var dismiss

    @State private var model: ProjectWizardModel
    private let creator: ProjectCreator
    private let onFinished: ((CreatedProject) -> Void)?

    init(maps: [OrganizationMap], creator: ProjectCreator = ProjectCreator(), onFinished: ((CreatedProject) -> Void)? = nil) {
        _model = State(initialValue: ProjectWizardModel(maps: maps))
        self.creator = creator
        self.onFinished = onFinished
    }

    var body: some View {
        @Bindable var model = model
        return NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(24)
                .navigationTitle(Text(stepCaption))
                .toolbar { wizardToolbar }
        }
        .frame(width: 560, height: 500)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var stepCaption: LocalizedStringKey {
        switch model.step {
        case .map: "wizard.step.map"
        case .details: "wizard.step.details"
        case .success: "wizard.step.success"
        }
    }

    @ToolbarContentBuilder
    private var wizardToolbar: some ToolbarContent {
        if model.step != .success {
            ToolbarItem(placement: .cancellationAction) {
                Button("common.cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        switch model.step {
        case .map:
            ToolbarItem(placement: .confirmationAction) {
                Button("common.continue") {
                    model.goToDetails(locale: languageStore.locale)
                }
                .disabled(!model.canContinueFromMap)
                .keyboardShortcut(.defaultAction)
            }
        case .details:
            ToolbarItem(placement: .automatic) {
                Button("common.back", action: model.goBack)
                    .disabled(model.isCreating)
            }
            ToolbarItem(placement: .confirmationAction) {
                if model.isCreating {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button("wizard.create") {
                        model.createProject(creator: creator, recents: recents, locale: languageStore.locale)
                    }
                    .disabled(!model.canCreate)
                    .keyboardShortcut(.defaultAction)
                }
            }
        case .success:
            ToolbarItem(placement: .confirmationAction) {
                Button("common.done") {
                    if let created = model.created {
                        onFinished?(created)
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.step {
        case .map:
            mapStep
        case .details:
            detailsStep
        case .success:
            successStep
        }
    }

    private var mapStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("wizard.map.help")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if model.maps.isEmpty {
                errorBanner(AppFailure(MapCatalogError.noValidMaps([]), locale: languageStore.locale))
            } else {
                ForEach(model.maps) { map in
                    mapCard(map)
                }
            }

            if let failure = model.failure {
                errorBanner(failure)
            }
        }
    }

    private func mapCard(_ map: OrganizationMap) -> some View {
        let selected = model.selectedMapID == map.id
        return Button {
            model.selectedMapID = map.id
            model.failure = nil
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 4) {
                    Text(map.name.resolved(language: languageStore.language))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("wizard.map.slots \(map.slots.count)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(selected ? Color.accentColor : Color(nsColor: .separatorColor).opacity(0.6), lineWidth: selected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var detailsStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("wizard.location.label")
                    .font(.headline)
                Text(model.parentPath.isEmpty ? String(localized: "wizard.location.empty", locale: languageStore.locale) : model.parentPath)
                    .foregroundStyle(model.parentPath.isEmpty ? .secondary : .primary)
                    .lineLimit(2)
                    .textSelection(.enabled)
                Button {
                    model.chooseParent(locale: languageStore.locale)
                } label: {
                    Label("wizard.location.choose", systemImage: "folder.badge.plus")
                }
                .help(Text("wizard.location.choose.hint"))
                if let locationError = model.locationError {
                    Text(locationError.message)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("wizard.name.label")
                    .font(.headline)
                TextField("wizard.name.placeholder", text: $model.projectName)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: model.projectName) { _, _ in
                        model.nameError = nil
                    }
                Text("wizard.name.help")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let nameError = model.nameError {
                    Text(nameError.message)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }

            if let failure = model.failure {
                errorBanner(failure)
            }
        }
    }

    private var successStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("wizard.success.title", systemImage: "checkmark.circle.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
            if let created = model.created {
                Text(created.metadata.displayName)
                    .font(.headline)
                Text(created.url.path)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Text("wizard.success.body")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    FinderReveal.reveal(created.url)
                } label: {
                    Label("wizard.success.reveal", systemImage: "folder")
                }
                .help(Text("wizard.success.reveal.hint"))
            }
            if let failure = model.failure {
                errorBanner(failure)
            }
        }
    }

    private func errorBanner(_ failure: AppFailure) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(failure.message, systemImage: "exclamationmark.triangle")
            if failure.debugDescription != failure.message {
                Text(failure.debugDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
