import SwiftUI

struct AppStatusItem {
    var icon: String? = nil
    var text: String
    var tint: Color = .secondary
}

struct AppStatusBar<Trailing: View>: View {
    var items: [AppStatusItem]
    var trailing: Trailing

    init(items: [AppStatusItem], @ViewBuilder trailing: () -> Trailing) {
        self.items = items
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.35))
                        .frame(width: 1, height: 12)
                        .padding(.horizontal, 8)
                }
                HStack(spacing: 5) {
                    if let icon = item.icon {
                        Image(systemName: icon)
                            .font(.caption)
                    }
                    Text(item.text)
                        .lineLimit(1)
                }
                .foregroundStyle(item.tint)
            }
            Spacer(minLength: 8)
            trailing
            StatusSettingsButton()
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 26, alignment: .leading)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
        .accessibilityElement(children: .combine)
    }
}

extension AppStatusBar where Trailing == EmptyView {
    init(items: [AppStatusItem]) {
        self.init(items: items) { EmptyView() }
    }
}

struct StatusSettingsButton: View {
    var body: some View {
        SettingsLink {
            Image(systemName: "gearshape")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(Text("settings.title.hint"))
        .accessibilityLabel(Text("settings.title"))
        .padding(.leading, 8)
    }
}
