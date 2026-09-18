import SwiftUI
import UniformTypeIdentifiers

struct ReviewGridView: View {
    @Environment(ProjectSession.self) private var session
    @Environment(AppLanguageStore.self) private var languageStore
    @Environment(ThumbnailSizeStore.self) private var thumbnailSize

    var body: some View {
        GeometryReader { geo in
            let thumb = thumbnailSize.resolvedSize
            ScrollView {
                let parts = session.reviewSlotPartitions()
                LazyVStack(alignment: .leading, spacing: 16) {
                    if !parts.special.isEmpty {
                        specialGroup(parts.special, thumbSize: thumb)
                    }
                    ForEach(parts.regular) { slot in
                        folderCard(slot, emphasized: false, thumbSize: thumb)
                    }
                }
                .padding(20)
            }
            .preference(key: ReviewWidthKey.self, value: geo.size.width)
        }
        .onPreferenceChange(ReviewWidthKey.self) { width in
            syncLayout(width: width)
        }
        .onChange(of: session.photos.count) { _, _ in
            thumbnailSize.updateLayout(width: thumbnailSize.layoutWidth, photoCount: maxPhotoCount)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dropDestination(for: URL.self) { urls, _ in
            Task { await session.importURLs(urls, locale: languageStore.locale) }
            return true
        }
    }

    private var maxPhotoCount: Int {
        session.displaySlots().map { session.photos(in: $0).count }.max() ?? 0
    }

    private func syncLayout(width: CGFloat) {
        thumbnailSize.updateLayout(width: max(width - 56, 1), photoCount: maxPhotoCount)
    }

    private func specialGroup(_ slots: [Slot], thumbSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(slots) { slot in
                slotContent(slot, thumbSize: thumbSize)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.28), lineWidth: 1.2)
        }
    }

    private func folderCard(_ slot: Slot, emphasized: Bool, thumbSize: CGFloat) -> some View {
        slotContent(slot, thumbSize: thumbSize)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(emphasized ? 0.28 : 0.08), lineWidth: 1)
            }
    }

    private func slotContent(_ slot: Slot, thumbSize: CGFloat) -> some View {
        let items = session.photos(in: slot)
        return VStack(alignment: .leading, spacing: 8) {
            rowHeader(slot: slot, count: items.count)
            LiveReorderStrip(
                items: items,
                size: thumbSize,
                revision: session.imageRevision,
                onTap: { photo in
                    session.startTriage(slot: slot, startingAt: photo)
                },
                onCommitMove: { from, to in
                    session.reorder(in: slot, from: from, to: to, locale: languageStore.locale)
                }
            )
        }
    }

    private func rowHeader(slot: Slot, count: Int) -> some View {
        HStack(spacing: 8) {
            Text(slotTitle(slot))
                .font(.headline)
            if let expected = slot.expectedCount {
                Text("\(count)/\(expected)")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(count == expected ? Color.secondary : Color.orange)
            } else {
                Text("\(count)")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func slotTitle(_ slot: Slot) -> String {
        let locale = languageStore.locale
        if slot.isInbox {
            return String(localized: "workspace.inbox.label", locale: locale)
        }
        if slot.isGeneral {
            return String(localized: "workspace.slot.general", locale: locale)
        }
        if slot.isTrash {
            return String(localized: "workspace.slot.trash", locale: locale)
        }
        return slot.folder
    }
}

private struct ReviewWidthKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ThumbnailSizeControls: View {
    @Environment(ThumbnailSizeStore.self) private var thumbnailSize

    var body: some View {
        HStack(spacing: 2) {
            IconActionButton(
                systemImage: "minus",
                help: "review.thumbs.smaller",
                hint: "review.thumbs.smaller.hint",
                hintPlacement: .above,
                isDisabled: !thumbnailSize.canShrink,
                compact: true
            ) {
                thumbnailSize.makeSmaller(currentSize: thumbnailSize.resolvedSize)
            }
            Button(action: thumbnailSize.useAutomatic) {
                Text("review.thumbs.automatic")
                    .font(.caption2.weight(thumbnailSize.mode == .automatic ? .semibold : .regular))
                    .foregroundStyle(thumbnailSize.mode == .automatic ? Color.primary : Color.secondary)
                    .padding(.horizontal, 6)
                    .frame(height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.primary.opacity(thumbnailSize.mode == .automatic ? 0.10 : 0.04))
                    )
            }
            .buttonStyle(.plain)
            .hoverHint("review.thumbs.automatic", hint: "review.thumbs.automatic.hint", placement: .above)
            .accessibilityLabel(Text("review.thumbs.automatic"))
            IconActionButton(
                systemImage: "plus",
                help: "review.thumbs.larger",
                hint: "review.thumbs.larger.hint",
                hintPlacement: .above,
                isDisabled: !thumbnailSize.canGrow,
                compact: true
            ) {
                thumbnailSize.makeLarger(currentSize: thumbnailSize.resolvedSize)
            }
        }
    }
}
