import SwiftUI

struct PhotoCropOverlay: View {
    let imageFrame: CGRect
    @Binding var crop: CGRect

    @State private var dragStart: CGRect?

    var body: some View {
        let viewCrop = rect(inView: crop)
        ZStack(alignment: .topLeading) {
            dimming(outside: viewCrop)
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .strokeBorder(Color.white, lineWidth: 1.5)
                .background(Color.white.opacity(0.04))
                .frame(width: viewCrop.width, height: viewCrop.height)
                .offset(x: viewCrop.minX, y: viewCrop.minY)
                .gesture(drag(.move))
            ForEach(Array(edgeHandles), id: \.handle) { item in
                handleView(at: item.point, handle: item.handle)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .allowsHitTesting(true)
    }

    private var edgeHandles: [(handle: PhotoCropGeometry.Handle, point: CGPoint)] {
        let viewCrop = rect(inView: crop)
        return [
            (.northWest, CGPoint(x: viewCrop.minX, y: viewCrop.minY)),
            (.north, CGPoint(x: viewCrop.midX, y: viewCrop.minY)),
            (.northEast, CGPoint(x: viewCrop.maxX, y: viewCrop.minY)),
            (.east, CGPoint(x: viewCrop.maxX, y: viewCrop.midY)),
            (.southEast, CGPoint(x: viewCrop.maxX, y: viewCrop.maxY)),
            (.south, CGPoint(x: viewCrop.midX, y: viewCrop.maxY)),
            (.southWest, CGPoint(x: viewCrop.minX, y: viewCrop.maxY)),
            (.west, CGPoint(x: viewCrop.minX, y: viewCrop.midY))
        ]
    }

    private func dimming(outside viewCrop: CGRect) -> some View {
        Path { path in
            path.addRect(imageFrame)
            path.addRect(viewCrop)
        }
        .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
        .allowsHitTesting(false)
    }

    private func handleView(at point: CGPoint, handle: PhotoCropGeometry.Handle) -> some View {
        let size: CGFloat = handle.isCorner ? 12 : 10
        return RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(Color.white)
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
            .offset(x: point.x - size / 2, y: point.y - size / 2)
            .gesture(drag(handle))
    }

    private func drag(_ handle: PhotoCropGeometry.Handle) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if dragStart == nil { dragStart = crop }
                guard let start = dragStart, imageFrame.width > 0, imageFrame.height > 0 else { return }
                crop = PhotoCropGeometry.apply(
                    handle: handle,
                    to: start,
                    dx: value.translation.width / imageFrame.width,
                    dy: value.translation.height / imageFrame.height
                )
            }
            .onEnded { _ in
                dragStart = nil
            }
    }

    private func rect(inView normalized: CGRect) -> CGRect {
        CGRect(
            x: imageFrame.minX + normalized.minX * imageFrame.width,
            y: imageFrame.minY + normalized.minY * imageFrame.height,
            width: normalized.width * imageFrame.width,
            height: normalized.height * imageFrame.height
        )
    }
}
