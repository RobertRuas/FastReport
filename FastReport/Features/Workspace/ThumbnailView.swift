import AppKit
import SwiftUI

struct ThumbnailView: View {
    let url: URL
    var size: CGFloat = 72
    var revision: Int = 0
    var onRotate: (() -> Void)? = nil
    var onTrash: (() -> Void)? = nil

    @State private var hovering = false

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
        .overlay(alignment: .topTrailing) {
            if showsActions {
                actions
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onHover { hovering = $0 }
    }

    private var showsActions: Bool {
        onRotate != nil || onTrash != nil
    }

    private var actions: some View {
        HStack(spacing: 2) {
            if let onRotate {
                ThumbnailCornerButton(systemImage: "rotate.right", help: "triage.rotate", hint: "triage.rotate.hint", action: onRotate)
            }
            if let onTrash {
                ThumbnailCornerButton(systemImage: "trash", help: "triage.trash", hint: "triage.trash.hint", action: onTrash)
            }
        }
        .padding(3)
        .opacity(hovering ? 1 : 0.72)
    }
}

private struct ThumbnailCornerButton: View {
    let systemImage: String
    let help: LocalizedStringKey
    let hint: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 16, height: 16)
                .background(Circle().fill(.black.opacity(0.48)))
        }
        .buttonStyle(.plain)
        .help(Text(hint))
        .accessibilityLabel(Text(help))
    }
}
