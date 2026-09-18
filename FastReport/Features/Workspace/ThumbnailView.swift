import AppKit
import SwiftUI

struct ThumbnailView: View {
    let url: URL
    var size: CGFloat = 72
    var revision: Int = 0

    var body: some View {
        Group {
            if let image = ThumbnailStore.shared.image(for: url, revision: revision, maxPixelSize: max(96, Int(size * 2))) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
