import SwiftUI

struct AppStatusItem {
    var icon: String? = nil
    var text: String
    var tint: Color = .secondary
}

struct AppStatusBar: View {
    var items: [AppStatusItem]

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
            Spacer(minLength: 0)
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
