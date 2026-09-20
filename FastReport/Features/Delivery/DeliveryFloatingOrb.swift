import SwiftUI

struct DeliveryFloatingOrb: View {
    var systemImage: String
    var help: LocalizedStringKey
    var hint: LocalizedStringKey
    var tint: Color
    var isBusy: Bool
    var offset: CGSize
    var onExpand: () -> Void
    var onOffset: (CGSize) -> Void

    @State private var dragOrigin: CGSize?
    @State private var moved = false

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 34, height: 34)
            .background(.regularMaterial, in: Circle())
            .overlay {
                Circle()
                    .strokeBorder(Color.white.opacity(isBusy ? 0.8 : 0.45), lineWidth: isBusy ? 1.6 : 1)
            }
            .overlay {
                Circle()
                    .strokeBorder(tint.opacity(isBusy ? 0.75 : 0.35), lineWidth: 1)
            }
            .shadow(color: tint.opacity(0.55), radius: isBusy ? 10 : 7)
            .shadow(color: Color.white.opacity(0.42), radius: 5)
            .shadow(color: .black.opacity(0.16), radius: 3, y: 1)
            .offset(offset)
            .contentShape(Circle())
            .gesture(press)
            .hoverHint(help, hint: hint, placement: .above)
            .accessibilityLabel(Text(help))
            .accessibilityAddTraits(.isButton)
    }

    private var press: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let distance = hypot(value.translation.width, value.translation.height)
                if distance >= 5 {
                    moved = true
                    if dragOrigin == nil { dragOrigin = offset }
                    let origin = dragOrigin ?? .zero
                    onOffset(
                        CGSize(
                            width: origin.width + value.translation.width,
                            height: origin.height + value.translation.height
                        )
                    )
                }
            }
            .onEnded { value in
                let distance = hypot(value.translation.width, value.translation.height)
                dragOrigin = nil
                if !moved && distance < 5 {
                    onExpand()
                }
                moved = false
            }
    }
}
