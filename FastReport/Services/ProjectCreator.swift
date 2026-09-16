import Foundation

struct ProjectCreator {
    var fileManager: FileManager = .default
    var bookmarkStore: any BookmarkStoring = SecurityScopedBookmarkStore()
    var now: @Sendable () -> Date = { Date() }

    func create(
        map: OrganizationMap,
        parent: URL,
        displayName: String,
        locale: Locale = Locale(identifier: "pt")
    ) throws -> CreatedProject {
        do {
            try MapValidator.validate(map)
        } catch {
            throw ProjectCreateError.invalidMap
        }

        let name = try ProjectFolderName.validate(displayName)
        let parent = parent.standardizedFileURL

        var isDirectory: ObjCBool = false
        if !fileManager.fileExists(atPath: parent.path, isDirectory: &isDirectory) {
            throw ProjectCreateError.parentMissing
        }
        if !isDirectory.boolValue {
            throw ProjectCreateError.parentNotDirectory
        }

        let accessed = parent.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                parent.stopAccessingSecurityScopedResource()
            }
        }

        if !fileManager.isWritableFile(atPath: parent.path) {
            throw ProjectCreateError.parentInaccessible
        }

        let projectURL = parent.appendingPathComponent(name, isDirectory: true)
        if fileManager.fileExists(atPath: projectURL.path) {
            throw ProjectCreateError.alreadyExists(name)
        }

        do {
            try fileManager.createDirectory(at: projectURL, withIntermediateDirectories: false)
        } catch {
            throw mappedCreateError(error, name: name)
        }

        do {
            try createSlotFolders(map: map, projectURL: projectURL)
            let metadata = try writeMetadata(map: map, displayName: name, projectURL: projectURL)
            let bookmark = makeBookmark(for: projectURL, locale: locale)
            return CreatedProject(
                url: projectURL,
                metadata: metadata,
                bookmarkData: bookmark.data,
                bookmarkWarning: bookmark.warning
            )
        } catch {
            try? fileManager.removeItem(at: projectURL)
            throw error
        }
    }

    private func createSlotFolders(map: OrganizationMap, projectURL: URL) throws {
        let folders = orderedUniqueFolders(in: map)
        for folder in folders {
            guard MapValidator.isSafeFolderName(folder) else {
                throw ProjectCreateError.invalidMap
            }
            let url = projectURL.appendingPathComponent(folder, isDirectory: true)
            do {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: false)
            } catch {
                throw ProjectCreateError.createFailed(error.localizedDescription)
            }
        }
    }

    private func writeMetadata(map: OrganizationMap, displayName: String, projectURL: URL) throws -> ProjectMetadata {
        let metadata = try ProjectMetadata(
            mapId: map.id,
            displayName: displayName,
            createdAt: now()
        ).validated()

        let data: Data
        do {
            data = try ProjectMetadata.makeEncoder().encode(metadata)
        } catch {
            throw ProjectCreateError.writeMetadataFailed(error.localizedDescription)
        }

        let fileURL = projectURL.appendingPathComponent(ProjectMetadata.fileName)
        let temporaryURL = projectURL.appendingPathComponent("\(ProjectMetadata.fileName).tmp")
        do {
            try data.write(to: temporaryURL, options: [.atomic])
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
            try fileManager.moveItem(at: temporaryURL, to: fileURL)
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw ProjectCreateError.writeMetadataFailed(error.localizedDescription)
        }
        return metadata
    }

    private func makeBookmark(for url: URL, locale: Locale) -> (data: Data?, warning: AppFailure?) {
        do {
            return (try bookmarkStore.save(projectURL: url), nil)
        } catch {
            return (
                nil,
                AppFailure(
                    code: "project.bookmark",
                    message: String(localized: "error.project.bookmark", locale: locale),
                    debugDescription: error.localizedDescription
                )
            )
        }
    }

    private func orderedUniqueFolders(in map: OrganizationMap) -> [String] {
        var seen = Set<String>()
        var folders: [String] = []
        for slot in map.slots {
            if seen.insert(slot.folder).inserted {
                folders.append(slot.folder)
            }
        }
        return folders
    }

    private func mappedCreateError(_ error: Error, name: String) -> ProjectCreateError {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileWriteFileExistsError {
            return .alreadyExists(name)
        }
        return .createFailed(nsError.localizedDescription)
    }
}
