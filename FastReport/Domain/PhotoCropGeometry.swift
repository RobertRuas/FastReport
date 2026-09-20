import CoreGraphics

enum PhotoCropGeometry {
    static let minFraction: CGFloat = 0.05
    static let startInset: CGFloat = 0.08

    static var initial: CGRect {
        CGRect(
            x: startInset,
            y: startInset,
            width: 1 - startInset * 2,
            height: 1 - startInset * 2
        )
    }

    static func fittedImageRect(imageSize: CGSize, in bounds: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, bounds.width > 0, bounds.height > 0 else {
            return .zero
        }
        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: bounds.minX + (bounds.width - size.width) / 2,
            y: bounds.minY + (bounds.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    static func clamp(_ rect: CGRect) -> CGRect {
        var width = min(max(rect.width, minFraction), 1)
        var height = min(max(rect.height, minFraction), 1)
        var x = rect.origin.x
        var y = rect.origin.y
        if x < 0 { x = 0 }
        if y < 0 { y = 0 }
        if x + width > 1 { x = 1 - width }
        if y + height > 1 { y = 1 - height }
        if x < 0 {
            x = 0
            width = 1
        }
        if y < 0 {
            y = 0
            height = 1
        }
        return CGRect(x: x, y: y, width: width, height: height)
    }

    static func apply(handle: Handle, to start: CGRect, dx: CGFloat, dy: CGFloat) -> CGRect {
        var next = start
        switch handle {
        case .move:
            next.origin.x += dx
            next.origin.y += dy
        case .north:
            next.origin.y += dy
            next.size.height -= dy
        case .south:
            next.size.height += dy
        case .west:
            next.origin.x += dx
            next.size.width -= dx
        case .east:
            next.size.width += dx
        case .northWest:
            next.origin.x += dx
            next.origin.y += dy
            next.size.width -= dx
            next.size.height -= dy
        case .northEast:
            next.origin.y += dy
            next.size.width += dx
            next.size.height -= dy
        case .southWest:
            next.origin.x += dx
            next.size.width -= dx
            next.size.height += dy
        case .southEast:
            next.size.width += dx
            next.size.height += dy
        }
        return clamp(next)
    }

    enum Handle: Hashable, CaseIterable {
        case move
        case north, south, east, west
        case northWest, northEast, southWest, southEast

        var isCorner: Bool {
            switch self {
            case .northWest, .northEast, .southWest, .southEast: true
            default: false
            }
        }
    }
}
