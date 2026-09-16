import Foundation
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
    var showsBanner: Bool = false
    var downloadReceived: UInt64 = 0
    var downloadExpected: UInt64 = 0
    var extractionProgress: Double = 0
    var automaticallyChecksForUpdates: Bool

    var hasUpdateBadge: Bool {
        available != nil && phase != .installing && phase != .installed
    }

    var showsProgressOverlay: Bool {
        switch phase {
        case .checking, .downloading, .extracting, .readyToInstall, .installing, .installed:
            return true
        default:
            return false
        }
    }

    var overallProgress: Double {
        switch phase {
        case .checking:
            return 0
        case .downloading:
            guard downloadExpected > 0 else { return 0.02 }
            return min(0.72, 0.72 * Double(downloadReceived) / Double(downloadExpected))
        case .extracting:
            return 0.72 + (0.18 * max(0, min(1, extractionProgress)))
        case .readyToInstall:
            return 0.92
        case .installing:
            return 0.97
        case .installed:
            return 1
        case .upToDate:
            return 1
        default:
            return 0
        }
    }

    var isProgressDeterminate: Bool {
        switch phase {
        case .downloading:
            return downloadExpected > 0
        case .extracting, .readyToInstall:
            return true
        default:
            return false
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: Self.autoCheckKey) == nil {
            defaults.set(true, forKey: Self.autoCheckKey)
        }
        automaticallyChecksForUpdates = defaults.object(forKey: Self.autoCheckKey) as? Bool ?? true
        defaults.set(false, forKey: "fastreport.updates.autoInstall")
        defaults.set(false, forKey: "SUAutomaticallyUpdate")
        driver = SparkleUserDriver()
        driver.center = self
        startSparkleIfNeeded()
    }

    func setAutomaticallyChecks(_ enabled: Bool) {
        automaticallyChecksForUpdates = enabled
        defaults.set(enabled, forKey: Self.autoCheckKey)
        updater?.automaticallyChecksForUpdates = enabled
        if enabled {
            checkInBackground(force: true)
        }
    }

    func checkForUpdatesUserInitiated() {
        guard let updater else {
            statusMessage = String(localized: "settings.updates.unconfigured")
            phase = .failed
            return
        }
        showsBanner = false
        phase = .checking
        statusMessage = String(localized: "settings.updates.checking")
        updater.checkForUpdates()
    }

    func checkInBackground(force: Bool = false) {
        guard automaticallyChecksForUpdates, let updater else { return }
        if !force, let lastBackgroundCheck, Date().timeIntervalSince(lastBackgroundCheck) < 30 * 60 {
            return
        }
        lastBackgroundCheck = Date()
        updater.checkForUpdatesInBackground()
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

    func dismissBanner() {
        showsBanner = false
        pendingUpdateChoice?(.dismiss)
        pendingUpdateChoice = nil
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
            showsBanner = true
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
        available = info
        phase = alreadyDownloaded ? .readyToInstall : .available
        statusMessage = String(localized: "settings.updates.available \(info.version)")
        if !userInitiated || !showsProgressOverlay {
            showsBanner = true
        }
    }

    fileprivate func noteChecking() {
        phase = .checking
        statusMessage = String(localized: "settings.updates.checking")
    }

    fileprivate func noteNotFound() {
        available = nil
        showsBanner = false
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
        showsBanner = true
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
        showsBanner = true
    }

    fileprivate func noteInstalling() {
        phase = .installing
        statusMessage = String(localized: "settings.updates.progress.install")
    }

    fileprivate func noteInstalledNeedsReopen() {
        phase = .installed
        showsBanner = false
        available = nil
        statusMessage = String(localized: "settings.updates.installed.reopen")
    }

    func dismissInstalledNotice() {
        phase = .idle
        statusMessage = ""
        showsBanner = false
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
        updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
        updater.automaticallyDownloadsUpdates = false
        updater.updateCheckInterval = Self.checkInterval
        do {
            try updater.start()
            updater.automaticallyDownloadsUpdates = false
            self.updater = updater
            if automaticallyChecksForUpdates {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                    self?.checkInBackground(force: true)
                }
            }
        } catch {
            statusMessage = AppFailure(error, locale: Locale.current).message
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
            if alreadyDownloaded {
                center.pendingInstallChoice = reply
                center.noteReadyToInstall()
                return
            }
            center.pendingUpdateChoice = reply
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
            center?.noteNotFound()
            acknowledgement()
        }
        _ = error
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
            center.noteError(AppFailure(error, locale: Locale.current).message)
        }
    }

    func showDownloadInitiated(cancellation: @escaping () -> Void) {
        Task { @MainActor in
            center?.cancelDownload = cancellation
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
            guard let center else {
                reply(.install)
                return
            }
            center.pendingInstallChoice = reply
            center.noteReadyToInstall()
        }
    }

    func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool, retryTerminatingApplication: @escaping () -> Void) {
        Task { @MainActor in
            center?.noteInstalling()
        }
        _ = applicationTerminated
        _ = retryTerminatingApplication
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
                center?.showsBanner = true
            }
        }
    }

    func dismissUpdateInstallation() {
        Task { @MainActor in
            center?.noteDismissed()
        }
    }
}

enum SparkleInstallError {
    static let sparkleDomain = "SUSparkleErrorDomain"
    static let canceledCodes: Set<Int> = [4002, 4005]

    static func isCancellation(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == sparkleDomain && canceledCodes.contains(nsError.code)
    }

    static func happenedAfterInstallStarted(_ phase: UpdatePhase) -> Bool {
        switch phase {
        case .extracting, .readyToInstall, .installing, .installed:
            return true
        default:
            return false
        }
    }
}
