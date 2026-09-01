import SwiftUI

/// One rounded slice of a segmented wheel: an annular sector with softened
/// corners, like an orange segment. Drawn centered in the given rect.
struct PetalWedgeShape: Shape {
    let centerAngle: Angle
    let sliceAngle: Angle
    let innerRadius: CGFloat
    let outerRadius: CGFloat
    var gapAngle: Angle = .degrees(3)
    var cornerRadius: CGFloat = 14

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let start = centerAngle - sliceAngle / 2 + gapAngle / 2
        let end = centerAngle + sliceAngle / 2 - gapAngle / 2
        let ringDepth = outerRadius - innerRadius
        let corner = min(cornerRadius, ringDepth / 2.5)
        let outerCornerSweep = Angle(radians: Double(corner / outerRadius))
        let innerCornerSweep = Angle(radians: Double(corner / max(innerRadius, corner)))

        var path = Path()
        path.move(to: polarPoint(center, radius: outerRadius - corner, angle: start))
        path.addQuadCurve(
            to: polarPoint(center, radius: outerRadius, angle: start + outerCornerSweep),
            control: polarPoint(center, radius: outerRadius, angle: start)
        )
        path.addArc(
            center: center, radius: outerRadius,
            startAngle: start + outerCornerSweep, endAngle: end - outerCornerSweep,
            clockwise: false
        )
        path.addQuadCurve(
            to: polarPoint(center, radius: outerRadius - corner, angle: end),
            control: polarPoint(center, radius: outerRadius, angle: end)
        )
        path.addLine(to: polarPoint(center, radius: innerRadius + corner, angle: end))
        path.addQuadCurve(
            to: polarPoint(center, radius: innerRadius, angle: end - innerCornerSweep),
            control: polarPoint(center, radius: innerRadius, angle: end)
        )
        path.addArc(
            center: center, radius: innerRadius,
            startAngle: end - innerCornerSweep, endAngle: start + innerCornerSweep,
            clockwise: true
        )
        path.addQuadCurve(
            to: polarPoint(center, radius: innerRadius + corner, angle: start),
            control: polarPoint(center, radius: innerRadius, angle: start)
        )
        path.closeSubpath()
        return path
    }

    private func polarPoint(_ center: CGPoint, radius: CGFloat, angle: Angle) -> CGPoint {
        CGPoint(
            x: center.x + radius * cos(angle.radians),
            y: center.y + radius * sin(angle.radians)
        )
    }
}
