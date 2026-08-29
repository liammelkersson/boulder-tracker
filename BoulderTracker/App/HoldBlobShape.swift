import SwiftUI

/// An organic blob shape mimicking a climbing hold, defined by per-corner
/// elliptical radii as fractions of the rect size (like CSS 8-value border-radius).
struct HoldBlobShape: Shape {
    struct CornerRadii {
        let horizontal: CGFloat
        let vertical: CGFloat

        init(_ horizontal: CGFloat, _ vertical: CGFloat) {
            self.horizontal = horizontal
            self.vertical = vertical
        }
    }

    let topLeading: CornerRadii
    let topTrailing: CornerRadii
    let bottomTrailing: CornerRadii
    let bottomLeading: CornerRadii

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + topLeading.horizontal * w, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - topTrailing.horizontal * w, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + topTrailing.vertical * h),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomTrailing.vertical * h))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - bottomTrailing.horizontal * w, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + bottomLeading.horizontal * w, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - bottomLeading.vertical * h),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeading.vertical * h))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topLeading.horizontal * w, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}
