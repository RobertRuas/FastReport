import Foundation

enum AppInstallLocation: Equatable, Sendable {
    case updatable
    case translocated
    case readOnlyVolume
    case removableVolume

    var blocksUpdates: Bool { self != .updatable }

    static func diagnose(
        bundleURL: URL,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> AppInstallLocation {
        let path = bundleURL.resolvingSymlinksInPath().path
        if path.contains("/AppTranslocation/") {
            return .translocated
        }
        if (try? bundleURL.resourceValues(forKeys: [.volumeIsReadOnlyKey]).volumeIsReadOnly) == true {
            return .readOnlyVolume
        }
        let appVolume = try? bundleURL.resourceValues(forKeys: [.volumeURLKey]).volume?.resolvingSymlinksInPath()
        let homeVolume = try? homeDirectory.resourceValues(forKeys: [.volumeURLKey]).volume?.resolvingSymlinksInPath()
        if let appVolume, let homeVolume, appVolume != homeVolume {
            return .removableVolume
        }
        return .updatable
    }
}

enum ApplicationMover {
    static func applicationsDirectory(fileManager: FileManager = .default) -> URL {
        fileManager.urls(for: .applicationDirectory, in: .localDomainMask)[0]
    }

    static func destinationURL(appName: String = "FastReport.app", fileManager: FileManager = .default) -> URL {
        applicationsDirectory(fileManager: fileManager).appendingPathComponent(appName)
    }

    static func copyToApplications(
        from source: URL,
        destination: URL,
        fileManager: FileManager = .default
    ) throws {
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: source, to: destination)
        var dest = destination
        var values = URLResourceValues()
        values.quarantineProperties = nil
        try? dest.setResourceValues(values)
    }
}
