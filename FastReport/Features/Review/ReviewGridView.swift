import SwiftUI
import UniformTypeIdentifiers

struct ReviewGridView: View {
    @Environment(ProjectSession.self) private var session
    @Environment(AppLanguageStore.self) private var languageStore

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                ForEach(session.displaySlots()) { slot in
                    slotRow(slot)
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dropDestination(for: URL.self) { urls, _ in
            Task { await session.importURLs(urls, locale: languageStore.locale) }
            return true
        }
    }

    private func slotRow(_ slot: Slot) -> some View {
        let items = session.photos(in: slot)
        return VStack(alignment: .leading, spacing: 8) {
            rowHeader(slot: slot, count: items.count)
            photoStrip(slot: slot, items: items)
        }
    }

    private func rowHeader(slot: Slot, count: Int) -> some View {
        HStack(spacing: 8) {
            Text(slot.isInbox ? String(localized: "workspace.inbox.label", locale: languageStore.locale) : slot.folder)
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

    private func photoStrip(slot: Slot, items: [DiskPhoto]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items) { photo in
                    ThumbnailView(url: photo.url, revision: session.imageRevision)
                        .onTapGesture {
                            session.startTriage(slot: slot, startingAt: photo)
                        }
                        .draggable(photo.id)
                        .dropDestination(for: String.self) { dropped, _ in
                            guard let draggedID = dropped.first,
                                  let from = items.firstIndex(where: { $0.id == draggedID }),
                                  let to = items.firstIndex(where: { $0.id == photo.id }),
                                  from != to
                            else { return false }
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                                session.reorder(in: slot, from: from, to: to, locale: languageStore.locale)
                            }
                            return true
                        }
                }
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.78), value: items.map(\.id))
            .padding(.vertical, 4)
        }
    }
}
