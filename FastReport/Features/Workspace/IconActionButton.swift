import SwiftUI

struct IconActionButton: View {
    var systemImage: String
    var help: LocalizedStringKey
    var tint: Color = .primary
    var filled: Bool = false
    var badge: Int? = nil
    var isDisabled: Bool = false
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(filled ? Color.white : (isDisabled ? Color.secondary : tint))
                    .frame(width: 30, height: 30)
                    .background {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(fillColor)
                    }
                if let badge, badge > 0 {
                    Text(badge > 99 ? "99+" : "\(badge)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.accentColor))
                        .offset(x: 6, y: -6)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onHover { hovering = $0 }
        .help(Text(help))
        .accessibilityLabel(Text(help))
    }

    private var fillColor: Color {
        if filled {
            return isDisabled ? Color.accentColor.opacity(0.35) : Color.accentColor
        }
        return Color.primary.opacity(hovering && !isDisabled ? 0.10 : 0.05)
    }
}
