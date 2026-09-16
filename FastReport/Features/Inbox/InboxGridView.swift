import SwiftUI

struct InboxGridView: View {
    @Environment(ProjectSession.self) private var session
    @Environment(AppLanguageStore.self) private var languageStore

    private let columns = [GridItem(.adaptive(minimum: 76, maximum: 88), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            importBar

            if session.inbox.isEmpty {
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(session.inbox) { photo in
                            ThumbnailView(url: photo.url, revision: session.imageRevision)
                                .onTapGesture {
                                    session.startTriage(startingAt: photo)
                                }
                                .help(photo.fileName)
                        }
                    }
                }
            }

            stats
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .dropDestination(for: URL.self) { urls, _ in
            Task { await session.importURLs(urls, locale: languageStore.locale) }
            return true
        }
    }

    private var importBar: some View {
        HStack {
            Text("import.drop")
                .foregroundStyle(.secondary)
            Spacer()
            Button("import.choose") {
                Task { await session.pickAndImport(locale: languageStore.locale) }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
        )
    }

    @ViewBuilder
    private var stats: some View {
        if let stats = session.stats {
            Text("import.stats \(stats.imported) \(stats.converted) \(stats.skipped) \(stats.failed.count)")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        if let progress = session.importProgress {
            ProgressView(value: Double(progress.done), total: Double(max(progress.total, 1)))
        }
    }
}
