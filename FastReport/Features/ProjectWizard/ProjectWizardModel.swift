import Foundation
import Observation

@MainActor
@Observable
final class ProjectWizardModel {
    enum Step: Int {
        case map = 1
        case details = 2
        case success = 3
    }

    let maps: [OrganizationMap]
    var step: Step = .map
    var selectedMapID: String?
    var parentURL: URL?
    var projectName: String = ""
    var isCreating = false
    var created: CreatedProject?
    var failure: AppFailure?
    var nameError: AppFailure?
    var locationError: AppFailure?

    var selectedMap: OrganizationMap? {
        maps.first { $0.id == selectedMapID }
    }

    var parentPath: String {
        guard let parentURL else { return "" }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = parentURL.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    var canContinueFromMap: Bool { selectedMap != nil }
    var canCreate: Bool {
        selectedMap != nil && parentURL != nil && !projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isCreating
    }

    init(maps: [OrganizationMap]) {
        self.maps = maps
        self.selectedMapID = maps.first?.id
        if maps.isEmpty {
            failure = AppFailure(MapCatalogError.noValidMaps([]), locale: Locale(identifier: "pt"))
        }
    }

    func goToDetails(locale: Locale) {
        failure = nil
        guard canContinueFromMap else {
            failure = AppFailure(
                code: "wizard.map.required",
                message: String(localized: "error.wizard.map.required", locale: locale)
            )
            return
        }
        step = .details
    }

    func goBack() {
        failure = nil
        nameError = nil
        locationError = nil
        if step == .details {
            step = .map
        }
    }

    func chooseParent(locale: Locale) {
        locationError = nil
        failure = nil
        if let url = DirectoryPicker.pickParentDirectory(locale: locale) {
            parentURL = url
        }
    }

    func createProject(creator: ProjectCreator, recents: RecentProjectsStore, locale: Locale) {
        failure = nil
        nameError = nil
        locationError = nil

        guard let map = selectedMap else {
            failure = AppFailure(
                code: "wizard.map.required",
                message: String(localized: "error.wizard.map.required", locale: locale)
            )
            step = .map
            return
        }
        guard let parentURL else {
            locationError = AppFailure(ProjectCreateError.parentMissing, locale: locale)
            return
        }

        do {
            _ = try ProjectFolderName.validate(projectName)
        } catch {
            nameError = AppFailure(error, locale: locale)
            return
        }

        isCreating = true
        defer { isCreating = false }

        do {
            let created = try creator.create(
                map: map,
                parent: parentURL,
                displayName: projectName,
                locale: locale
            )
            recents.remember(created)
            self.created = created
            if let warning = created.bookmarkWarning {
                failure = warning
            }
            step = .success
        } catch {
            let wrapped = AppFailure(error, locale: locale)
            if wrapped.code == ProjectFolderNameError.empty.code
                || wrapped.code == ProjectFolderNameError.invalid.code
                || wrapped.code == ProjectFolderNameError.tooLong.code {
                nameError = wrapped
            } else if wrapped.code == ProjectCreateError.parentMissing.code
                || wrapped.code == ProjectCreateError.parentNotDirectory.code
                || wrapped.code == ProjectCreateError.parentInaccessible.code {
                locationError = wrapped
            } else {
                failure = wrapped
            }
        }
    }
}
