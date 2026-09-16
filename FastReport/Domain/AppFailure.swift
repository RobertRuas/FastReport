import Foundation

/// Erro apresentado ao utilizador. Sempre com código estável e mensagem localizável.
struct AppFailure: LocalizedError, Equatable, Sendable {
    let code: String
    let message: String
    let debugDescription: String

    var errorDescription: String? { message }

    init(code: String, message: String, debugDescription: String? = nil) {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        self.code = trimmedCode.isEmpty ? "unknown" : trimmedCode
        self.message = trimmedMessage.isEmpty
            ? String(localized: "error.generic", locale: Locale(identifier: "pt"))
            : trimmedMessage
        self.debugDescription = (debugDescription?.isEmpty == false) ? debugDescription! : self.message
    }

    init(_ error: Error, locale: Locale = Locale(identifier: "pt")) {
        if let failure = error as? AppFailure {
            self = failure
            return
        }
        if let catalog = error as? MapCatalogError {
            self.init(
                code: catalog.code,
                message: catalog.localized(locale: locale),
                debugDescription: String(describing: catalog)
            )
            return
        }
        if let validation = error as? MapValidationError {
            self.init(
                code: "map.invalid",
                message: validation.localized(locale: locale),
                debugDescription: validation.issues.map(\.rawMessage).joined(separator: "; ")
            )
            return
        }
        if let name = error as? FileNameError {
            self.init(
                code: name.code,
                message: name.localized(locale: locale),
                debugDescription: String(describing: name)
            )
            return
        }
        if let slug = error as? ProjectSlugError {
            self.init(
                code: slug.code,
                message: slug.localized(locale: locale),
                debugDescription: String(describing: slug)
            )
            return
        }
        if let metadata = error as? ProjectMetadataError {
            self.init(
                code: metadata.code,
                message: metadata.localized(locale: locale),
                debugDescription: String(describing: metadata)
            )
            return
        }
        if let folder = error as? ProjectFolderNameError {
            self.init(
                code: folder.code,
                message: folder.localized(locale: locale),
                debugDescription: String(describing: folder)
            )
            return
        }
        if let create = error as? ProjectCreateError {
            self.init(
                code: create.code,
                message: create.localized(locale: locale),
                debugDescription: String(describing: create)
            )
            return
        }
        if let pipeline = error as? ImagePipelineError {
            self.init(code: pipeline.code, message: pipeline.localized(locale: locale), debugDescription: String(describing: pipeline))
            return
        }
        if let organizer = error as? OrganizerError {
            self.init(code: organizer.code, message: organizer.localized(locale: locale), debugDescription: String(describing: organizer))
            return
        }
        if let open = error as? ProjectOpenError {
            self.init(code: open.code, message: open.localized(locale: locale), debugDescription: String(describing: open))
            return
        }
        let nsError = error as NSError
        self.init(
            code: "\(nsError.domain).\(nsError.code)",
            message: String(localized: "error.generic", locale: locale),
            debugDescription: nsError.localizedDescription
        )
    }
}
