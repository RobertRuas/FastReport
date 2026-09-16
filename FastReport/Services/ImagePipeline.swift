import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ImageFile {
    static let jpegExtensions: Set<String> = ["jpg", "jpeg"]
    static let supportedExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "tif", "tiff", "gif", "bmp", "webp"
    ]

    static func isSupported(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    static func isJPEG(_ url: URL) -> Bool {
        jpegExtensions.contains(url.pathExtension.lowercased())
    }
}

enum ImagePipelineError: Error, Equatable {
    case notAnImage(String)
    case emptyImage(String)
    case writeFailed(String)
    case rotateFailed(String)

    var code: String {
        switch self {
        case .notAnImage: "image.not_an_image"
        case .emptyImage: "image.empty"
        case .writeFailed: "image.write"
        case .rotateFailed: "image.rotate"
        }
    }

    func localized(locale: Locale) -> String {
        switch self {
        case .notAnImage:
            String(localized: "error.image.not_an_image", locale: locale)
        case .emptyImage:
            String(localized: "error.image.empty", locale: locale)
        case .writeFailed:
            String(localized: "error.image.write", locale: locale)
        case .rotateFailed:
            String(localized: "error.image.rotate", locale: locale)
        }
    }
}

struct ImageExportSettings: Equatable, Sendable {
    var maxDimension: Int
    var quality: Double

    static let `default` = ImageExportSettings(maxDimension: 1024, quality: 0.85)

    func validated() throws -> ImageExportSettings {
        if maxDimension < 256 || maxDimension > 4096 {
            throw ImagePipelineError.writeFailed("maxDimension")
        }
        if quality < 0.4 || quality > 1 {
            throw ImagePipelineError.writeFailed("quality")
        }
        return self
    }
}

enum ImagePipeline {
    static func convertToJPEG(
        source: URL,
        destination: URL,
        settings: ImageExportSettings = .default
    ) throws {
        let settings = try settings.validated()
        guard ImageFile.isSupported(source) else {
            throw ImagePipelineError.notAnImage(source.lastPathComponent)
        }
        let accessed = source.startAccessingSecurityScopedResource()
        defer { if accessed { source.stopAccessingSecurityScopedResource() } }

        guard let image = makeNormalizedImage(from: source, maxDimension: settings.maxDimension) else {
            throw ImagePipelineError.emptyImage(source.lastPathComponent)
        }

        let temp = destination.deletingLastPathComponent()
            .appendingPathComponent("\(UUID().uuidString).jpeg")
        do {
            try writeJPEG(image, to: temp, quality: settings.quality)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: temp, to: destination)
        } catch {
            try? FileManager.default.removeItem(at: temp)
            throw ImagePipelineError.writeFailed(error.localizedDescription)
        }
    }

    static func rotateClockwise(at url: URL, settings: ImageExportSettings = .default) throws {
        let settings = try settings.validated()
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        guard let input = CIImage(contentsOf: url, options: [.applyOrientationProperty: true]) else {
            throw ImagePipelineError.rotateFailed(url.lastPathComponent)
        }
        let rotated = input.oriented(.right)
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cgImage = context.createCGImage(rotated, from: rotated.extent) else {
            throw ImagePipelineError.rotateFailed(url.lastPathComponent)
        }

        let temp = url.deletingLastPathComponent().appendingPathComponent("\(UUID().uuidString).jpeg")
        do {
            try writeJPEG(cgImage, to: temp, quality: settings.quality)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            try FileManager.default.moveItem(at: temp, to: url)
        } catch {
            try? FileManager.default.removeItem(at: temp)
            throw ImagePipelineError.rotateFailed(error.localizedDescription)
        }
    }

    static func thumbnail(from url: URL, maxPixelSize: Int = 96) -> CGImage? {
        makeNormalizedImage(from: url, maxDimension: maxPixelSize)
    }

    static func pixelSize(of url: URL) -> (Int, Int)? {
        guard let image = makeNormalizedImage(from: url, maxDimension: 10_000) else { return nil }
        return (image.width, image.height)
    }

    private static func makeNormalizedImage(from url: URL, maxDimension: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options as CFDictionary),
              CGImageSourceGetCount(source) > 0
        else { return nil }

        let thumbOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, maxDimension)
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary)
    }

    private static func writeJPEG(_ image: CGImage, to url: URL, quality: Double) throws {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw ImagePipelineError.writeFailed(url.lastPathComponent)
        }
        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        CGImageDestinationAddImage(dest, image, properties as CFDictionary)
        if !CGImageDestinationFinalize(dest) {
            throw ImagePipelineError.writeFailed(url.lastPathComponent)
        }
    }
}
