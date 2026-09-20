import Foundation
import AppKit
import Observation
@preconcurrency import Sparkle

enum UpdatePhase: Equatable {
    case idle
    case checking
    case available
    case downloading
    case extracting
    case readyToInstall
    case installing
    case installed
    case upToDate
    case failed
}

struct AvailableUpdateInfo: Equatable {
    var version: String
    var build: String
    var title: String
    var publishedAt: Date?
    var releaseNotes: String
    var isInformational: Bool
}

@MainActor
@Observable
final class AppUpdateCenter {
    static let autoCheckKey = "fastreport.updates.autoCheck"
    static let checkInterval: TimeInterval = 4 * 60 * 60

    private let defaults: UserDefaults
    @ObservationIgnored private var updater: SPUUpdater?
    @ObservationIgnored fileprivate let driver: SparkleUserDriver
    @ObservationIgnored fileprivate var pendingUpdateChoice: ((SPUUserUpdateChoice) -> Void)?
    @ObservationIgnored fileprivate var pendingInstallChoice: ((SPUUserUpdateChoice) -> Void)?
    @ObservationIgnored fileprivate var cancelDownload: (() -> Void)?
    @ObservationIgnored fileprivate var cancelCheck: (() -> Void)?
    @ObservationIgnored private var lastBackgroundCheck: Date?

    var phase: UpdatePhase = .idle
    var available: AvailableUpdateInfo?
    var statusMessage: String = ""
    var showsUpdateSheet: Bool = false
    var downloadReceived: UInt64 = 0
    var downloadExpected: UInt64 = 0
    var extractionProgress: Double = 0
    var automaticallyChecksForUpdates: Bool

    var requiresApplicationsFolder: Bool {
        AppInstallLocation.diagnose(bundleURL: Bundle.main.bundleURL).blocksUpdates
    }

    var showsToolbarUpdateIcon: Bool {
        if requiresApplicationsFolder { return false }
        switch phase {
        case .available, .downloading, .extracting, .readyToInstall, .installing, .installed:
            return true
        default:
            return available != nil
        }
    }

    var isUpdateInProgress: Bool {
        switch phase {
        case .downloading, .extracting, .installing:
            return true
        default:
            return false
        }
    }

    var showsProgressDetails: Bool {
        switch phase {
        case .checking, .downloading, .extracting, .readyToInstall, .installing:
            return true
        default:
            return false
        }
    }

    var overallProgress: Double {
        UpdateProgressMath.fraction(
            phase: phase,
            received: downloadReceived,
            expected: downloadExpected,
            extraction: extractionProgress
        )
    }

    var isProgressDeterminate: Bool {
        switch phase {
        case .downloading:
            return downloadExpected > 0
        case .extracting, .readyToInstall, .installing, .installed:
            return true
        default:
            return false
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        automaticallyChecksForUpdates = true
        defaults.set(true, forKey: Self.autoCheckKey)
        defaults.set(true, forKey: "fastreport.updates.autoInstall")
        defaults.set(true, forKey: "SUAutomaticallyUpdate")
        driver = SparkleUserDriver()
        driver.center = self
        startSparkleIfNeeded()
    }

    func setAutomaticallyChecks(_ enabled: Bool) {
        _ = enabled
        automaticallyChecksForUpdates = true
        defaults.set(true, forKey: Self.autoCheckKey)
        updater?.automaticallyChecksForUpdates = true
        updater?.automaticallyDownloadsUpdates = true
        checkInBackground(force: true)
    }

    func checkForUpdatesUserInitiated(presentSheet: Bool = true) {
        guard let updater else {
            statusMessage = String(localized: "settings.updates.unconfigured")
            phase = .failed
            if presentSheet { showsUpdateSheet = true }
            return
        }
        if requiresApplicationsFolder {
            noteError(String(localized: "error.updates.location"))
            if presentSheet { showsUpdateSheet = true }
            return
        }
        if presentSheet {
            showsUpdateSheet = true
        }
        phase = .checking
        statusMessage = String(localized: "settings.updates.checking")
        updater.checkForUpdates()
    }

    func presentUpdateSheet() {
        showsUpdateSheet = true
        if available == nil, phase != .checking, !isUpdateInProgress {
            checkForUpdatesUserInitiated(presentSheet: true)
        }
    }

    func dismissUpdateSheet() {
        showsUpdateSheet = false
    }

    func checkInBackground(force: Bool = false) {
        guard automaticallyChecksForUpdates, let updater else { return }
        guard !requiresApplicationsFolder else { return }
        if !force, let lastBackgroundCheck, Date().timeIntervalSince(lastBackgroundCheck) < 30 * 60 {
            return
        }
        lastBackgroundCheck = Date()
        updater.checkForUpdatesInBackground()
    }

    func moveToApplicationsFolder() {
        do {
            let destination = ApplicationMover.destinationURL()
            try ApplicationMover.copyToApplications(from: Bundle.main.bundleURL, destination: destination)
            let configuration = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.openApplication(at: destination, configuration: configuration) { [weak self] _, error in
                DispatchQueue.main.async {
                    if let error {
                        self?.noteError(SparkleInstallError.message(for: error, locale: .current))
                        return
                    }
                    NSApp.terminate(nil)
                }
            }
        } catch {
            noteError(String(localized: "settings.updates.move.failed"))
        }
    }

    func beginInstall() {
        if let pendingUpdateChoice {
            pendingUpdateChoice(.install)
            self.pendingUpdateChoice = nil
            return
        }
        if let pendingInstallChoice {
            pendingInstallChoice(.install)
            self.pendingInstallChoice = nil
            return
        }
        updater?.checkForUpdates()
    }

    func cancelCurrent() {
        cancelCheck?()
        cancelDownload?()
        pendingUpdateChoice?(.dismiss)
        pendingInstallChoice?(.dismiss)
        cancelCheck = nil
        cancelDownload = nil
        pendingUpdateChoice = nil
        pendingInstallChoice = nil
        if available != nil {
            phase = .available
        } else {
            phase = .idle
        }
    }

    fileprivate func applyFoundItem(_ item: SUAppcastItem, userInitiated: Bool, alreadyDownloaded: Bool) {
        let info = AvailableUpdateInfo(
            version: item.displayVersionString,
            build: item.versionString,
            title: item.title ?? item.displayVersionString,
            publishedAt: item.date,
            releaseNotes: Self.plainNotes(from: item.itemDescription),
            isInformational: item.isInformationOnlyUpdate
        )
        _ = userInitiated
        available = info
        phase = alreadyDownloaded ? .readyToInstall : .available
        statusMessage = String(localized: "settings.updates.available \(info.version)")
    }

    fileprivate func noteChecking() {
        phase = .checking
        statusMessage = String(localized: "settings.updates.checking")
    }

    fileprivate func noteNotFound() {
        available = nil
        phase = .upToDate
        statusMessage = String(localized: "settings.updates.current")
    }

    fileprivate func noteError(_ message: String) {
        phase = .failed
        statusMessage = message
    }

    fileprivate func noteDownloadStarted() {
        phase = .downloading
        downloadReceived = 0
        downloadExpected = 0
        statusMessage = String(localized: "settings.updates.progress.download")
    }

    fileprivate func noteDownloadProgress(expected: UInt64?, additional: UInt64?) {
        if let expected {
            downloadExpected = expected
            downloadReceived = 0
        }
        if let additional {
            downloadReceived += additional
            if downloadExpected < downloadReceived {
                downloadExpected = downloadReceived
            }
        }
        phase = .downloading
    }

    fileprivate func noteExtracting(_ progress: Double?) {
        phase = .extracting
        if let progress {
            extractionProgress = progress
        } else {
            extractionProgress = 0
        }
        statusMessage = String(localized: "settings.updates.progress.extract")
    }

    fileprivate func noteReadyToInstall() {
        phase = .readyToInstall
        statusMessage = String(localized: "settings.updates.progress.ready")
    }

    fileprivate func noteInstalling() {
        phase = .installing
        statusMessage = String(localized: "settings.updates.progress.install")
    }

    fileprivate func noteInstalledNeedsReopen() {
        phase = .installed
        available = nil
        statusMessage = String(localized: "settings.updates.installed.reopen")
    }

    func dismissInstalledNotice() {
        phase = .idle
        statusMessage = ""
        showsUpdateSheet = false
        available = nil
    }

    fileprivate func noteDismissed() {
        cancelDownload = nil
        cancelCheck = nil
        pendingUpdateChoice = nil
        pendingInstallChoice = nil
        switch phase {
        case .installing:
            noteInstalledNeedsReopen()
        case .installed:
            break
        case .available, .readyToInstall:
            if available != nil {
                phase = .available
            }
        case .upToDate, .failed:
            break
        default:
            phase = .idle
        }
    }

    private func startSparkleIfNeeded() {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        let updater = SPUUpdater(
            hostBundle: .main,
            applicationBundle: .main,
            userDriver: driver,
            delegate: driver
        )
        updater.automaticallyChecksForUpdates = true
        updater.automaticallyDownloadsUpdates = true
        updater.updateCheckInterval = Self.checkInterval
        do {
            try updater.start()
            updater.automaticallyChecksForUpdates = true
            updater.automaticallyDownloadsUpdates = true
            self.updater = updater
            if automaticallyChecksForUpdates {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                    self?.checkInBackground(force: true)
                }
            }
        } catch {
            statusMessage = SparkleInstallError.message(for: error, locale: Locale.current)
            phase = .failed
        }
    }

    private static func plainNotes(from html: String?) -> String {
        guard let html, !html.isEmpty else { return "" }
        var text = html
        let replacements = [("<br ?/?>", "\n"), ("</p>", "\n"), ("<[^>]+>", "")]
        for (pattern, template) in replacements {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                text = regex.stringByReplacingMatches(
                    in: text,
                    range: NSRange(text.startIndex..., in: text),
                    withTemplate: template
                )
            }
        }
        return text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum UpdateProgressMath {
    static func fraction(
        phase: UpdatePhase,
        received: UInt64,
        expected: UInt64,
        extraction: Double
    ) -> Double {
        switch phase {
        case .checking:
            return 0
        case .downloading:
            guard expected > 0 else { return 0.02 }
            return min(0.9, 0.9 * Double(received) / Double(expected))
        case .extracting:
            return 0.9 + (0.09 * max(0, min(1, extraction)))
        case .readyToInstall, .installing, .installed, .upToDate:
            return 1
        default:
            return 0
        }
    }
}

final class SparkleUserDriver: NSObject, SPUUserDriver, SPUUpdaterDelegate {
    weak var center: AppUpdateCenter?

    func show(_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void) {
        _ = request
        reply(SUUpdatePermissionResponse(automaticUpdateChecks: true, sendSystemProfile: false))
    }

    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
        Task { @MainActor in
            center?.cancelCheck = cancellation
            center?.noteChecking()
        }
    }

    func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void) {
        Task { @MainActor in
            guard let center else {
                reply(.dismiss)
                return
            }
            let alreadyDownloaded = state.stage != .notDownloaded
            center.applyFoundItem(appcastItem, userInitiated: state.userInitiated, alreadyDownloaded: alreadyDownloaded)
            if appcastItem.isInformationOnlyUpdate {
                center.pendingUpdateChoice = nil
                reply(.dismiss)
                return
            }
            center.showsUpdateSheet = true
            center.pendingUpdateChoice = nil
            center.pendingInstallChoice = nil
            reply(.install)
        }
    }

    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {
        guard let text = String(data: downloadData.data, encoding: .utf8), !text.isEmpty else { return }
        Task { @MainActor in
            guard var info = center?.available else { return }
            info.releaseNotes = text
            center?.available = info
        }
    }

    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: any Error) {
        _ = error
    }

    func showUpdateNotFoundWithError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        Task { @MainActor in
            if SparkleInstallError.isUnupdatableLocation(error) {
                center?.noteError(SparkleInstallError.message(for: error, locale: .current))
            } else {
                center?.noteNotFound()
            }
            acknowledgement()
        }
    }

    func showUpdaterError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        Task { @MainActor in
            defer { acknowledgement() }
            guard let center else { return }
            if SparkleInstallError.isCancellation(error) {
                center.phase = center.available == nil ? .idle : .available
                center.statusMessage = ""
                return
            }
            if SparkleInstallError.happenedAfterInstallStarted(center.phase) {
                center.noteInstalledNeedsReopen()
                return
            }
            center.noteError(SparkleInstallError.message(for: error, locale: .current))
        }
    }

    func showDownloadInitiated(cancellation: @escaping () -> Void) {
        _ = cancellation
        Task { @MainActor in
            center?.cancelDownload = nil
            center?.showsUpdateSheet = true
            center?.noteDownloadStarted()
        }
    }

    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
        Task { @MainActor in
            center?.noteDownloadProgress(expected: expectedContentLength, additional: nil)
        }
    }

    func showDownloadDidReceiveData(ofLength length: UInt64) {
        Task { @MainActor in
            center?.noteDownloadProgress(expected: nil, additional: length)
        }
    }

    func showDownloadDidStartExtractingUpdate() {
        Task { @MainActor in
            center?.noteExtracting(nil)
        }
    }

    func showExtractionReceivedProgress(_ progress: Double) {
        Task { @MainActor in
            center?.noteExtracting(progress)
        }
    }

    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        Task { @MainActor in
            center?.showsUpdateSheet = true
            center?.pendingInstallChoice = nil
            center?.noteReadyToInstall()
            reply(.install)
        }
    }

    func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool, retryTerminatingApplication: @escaping () -> Void) {
        Task { @MainActor in
            center?.showsUpdateSheet = true
            center?.noteInstalling()
            if !applicationTerminated {
                retryTerminatingApplication()
            }
        }
    }

    func updater(_ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem, immediateInstallationBlock immediateInstallHandler: @escaping () -> Void) -> Bool {
        _ = updater
        _ = item
        Task { @MainActor in
            center?.showsUpdateSheet = true
            center?.noteInstalling()
            immediateInstallHandler()
        }
        return true
    }

    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
        Task { @MainActor in
            if relaunched {
                center?.dismissInstalledNotice()
            } else {
                center?.noteInstalledNeedsReopen()
            }
            acknowledgement()
        }
    }

    func showUpdateInFocus() {
        Task { @MainActor in
            if center?.available != nil {
                center?.showsUpdateSheet = true
            }
        }
    }

    func dismissUpdateInstallation() {
        Task { @MainActor in
            center?.noteDismissed()
        }
    }
}
