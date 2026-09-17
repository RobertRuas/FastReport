import Foundation

enum SparkleInstallError {
    static let sparkleDomain = "SUSparkleErrorDomain"
    static let canceledCodes: Set<Int> = [4002, 4005, 4007]
    static let locationCodes: Set<Int> = [1003, 1005]
    static let noUpdateCode = 1001

    static func isCancellation(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == sparkleDomain && canceledCodes.contains(nsError.code)
    }

    static func isUnupdatableLocation(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == sparkleDomain && locationCodes.contains(nsError.code)
    }

    static func isNoUpdate(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == sparkleDomain && nsError.code == noUpdateCode
    }

    static func happenedAfterInstallStarted(_ phase: UpdatePhase) -> Bool {
        switch phase {
        case .extracting, .readyToInstall, .installing, .installed:
            return true
        default:
            return false
        }
    }

    static func message(for error: Error, locale: Locale) -> String {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return String(localized: "error.updates.network", locale: locale)
        }
        guard nsError.domain == sparkleDomain else {
            return String(localized: "error.updates.failed", locale: locale)
        }
        switch nsError.code {
        case 1003, 1005:
            return String(localized: "error.updates.location", locale: locale)
        case 1000, 1007:
            return String(localized: "error.updates.parse", locale: locale)
        case 1002, 2001:
            return String(localized: "error.updates.network", locale: locale)
        case 3001, 3002:
            return String(localized: "error.updates.signature", locale: locale)
        default:
            return String(localized: "error.updates.failed", locale: locale)
        }
    }
}
