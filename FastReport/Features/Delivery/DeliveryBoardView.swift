import SwiftUI

struct DeliveryBoardView: View {
    @Environment(ProjectSession.self) private var session
    @Environment(AppLanguageStore.self) private var languageStore
    @Environment(ThumbnailSizeStore.self) private var thumbnailSize

    var body: some View {
        GeometryReader { geo in
            let thumb = thumbnailSize.resolvedSize
            VStack(alignment: .leading, spacing: 0) {
                banner
                ScrollView {
                    let parts = session.deliverySlotPartitions()
                    LazyVStack(alignment: .leading, spacing: 16) {
                        if parts.special.isEmpty && parts.regular.isEmpty {
                            Text("workspace.delivery.empty")
                                .foregroundStyle(.secondary)
                                .padding(.top, 24)
                        }
                        if !parts.special.isEmpty {
                            folderGroup(parts.special, thumbSize: thumb, emphasized: true)
                        }
                        ForEach(parts.regular) { slot in
                            folderCard(slot, thumbSize: thumb)
                        }
                    }
                    .padding(20)
                }
            }
            .preference(key: DeliveryWidthKey.self, value: geo.size.width)
        }
        .onPreferenceChange(DeliveryWidthKey.self) { width in
            thumbnailSize.updateLayout(width: max(width - 56, 1), photoCount: maxPhotoCount)
        }
        .onChange(of: session.photos.count) { _, _ in
            thumbnailSize.updateLayout(width: thumbnailSize.layoutWidth, photoCount: maxPhotoCount)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var banner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "doc.text.image")
                .foregroundStyle(.secondary)
            Text("workspace.delivery.banner")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(String(
                localized: "status.delivery \(session.placedCount) \(session.classifiedCount)",
                locale: languageStore.locale
            ))
            .font(.callout.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.04))
    }

    private var maxPhotoCount: Int {
        session.deliveryDisplaySlots().map { session.photos(in: $0).count }.max() ?? 0
    }

    private func folderGroup(_ slots: [Slot], thumbSize: CGFloat, emphasized: Bool) -> some View {
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
                .strokeBorder(Color.primary.opacity(emphasized ? 0.28 : 0.08), lineWidth: 1.2)
        }
    }

    private func folderCard(_ slot: Slot, thumbSize: CGFloat) -> some View {
        slotContent(slot, thumbSize: thumbSize)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
    }

    private func slotContent(_ slot: Slot, thumbSize: CGFloat) -> some View {
        let items = session.photos(in: slot)
        let placed = items.filter { session.isPlaced($0) }.count
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(ReviewDisplaySlots.title(slot, locale: languageStore.locale))
                    .font(.headline)
                Text("\(placed)/\(items.count)")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(placed == items.count && !items.isEmpty ? Color.secondary : Color.primary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ThumbnailSizeStore.spacing) {
                    ForEach(items) { photo in
                        DeliveryThumbnailCell(photo: photo, size: thumbSize)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 2)
            }
        }
    }
}

private struct DeliveryThumbnailCell: View {
    @Environment(ProjectSession.self) private var session
    @Environment(AppLanguageStore.self) private var languageStore
    let photo: DiskPhoto
    let size: CGFloat

    var body: some View {
        let placed = session.isPlaced(photo)
        let locale = languageStore.locale
        ZStack(alignment: .topTrailing) {
            ThumbnailView(url: photo.url, size: size, revision: session.imageRevision)
                .opacity(placed ? 0.38 : 1)
                .overlay {
                    ExternalFileDragOverlay(
                        url: photo.url,
                        preview: ThumbnailStore.shared.image(
                            for: photo.url,
                            revision: session.imageRevision,
                            maxPixelSize: max(96, Int(size * 2))
                        ),
                        isPlaced: placed,
                        markTitle: String(localized: "workspace.delivery.mark", locale: locale),
                        unmarkTitle: String(localized: "workspace.delivery.unmark", locale: locale),
                        onPlaced: { session.markPlaced(photo) },
                        onToggle: { session.togglePlaced(photo) }
                    )
                }
            if placed {
                Image(systemName: "checkmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.accentColor)
                    .font(.system(size: 14))
                    .padding(4)
                    .allowsHitTesting(false)
            }
        }
        .hoverHint(verbatim: photo.fileName)
    }
}

private struct DeliveryWidthKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
