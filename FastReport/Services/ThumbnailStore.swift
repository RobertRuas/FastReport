import AppKit
import Foundation

@MainActor
final class ThumbnailStore {
    static let shared = ThumbnailStore()

    private let cache = NSCache<NSString, NSImage>()

    init() {
        cache.countLimit = 400
    }

    func image(for url: URL, revision: Int = 0) -> NSImage? {
        let key = cacheKey(for: url, revision: revision)
        if let cached = cache.object(forKey: key as NSString) {
            return cached
        }
        guard let cg = ImagePipeline.thumbnail(from: url) else { return nil }
        let image = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        cache.setObject(image, forKey: key as NSString)
        return image
    }

    func invalidate(url: URL) {
        cache.removeAllObjects()
    }

    func removeAll() {
        cache.removeAllObjects()
    }

    private func cacheKey(for url: URL, revision: Int) -> String {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        let stamp = values?.contentModificationDate?.timeIntervalSince1970 ?? 0
        return "\(url.standardizedFileURL.path)|\(stamp)|\(revision)"
    }
}
