import SwiftUI

/// Faint triangulated "climbing wall" backdrop, like the mockup's tiled SVG texture.
struct WallTexture: View {
    @Environment(\.palette) private var palette

    private static let cellSize: CGFloat = 90

    var body: some View {
        Canvas { context, size in
            var seed: UInt64 = 11
            func nextRandom() -> Double {
                seed = (seed &* 9301 &+ 49297) % 233280
                return Double(seed) / 233280
            }
            let cols = Int(ceil(size.width / Self.cellSize))
            let rows = Int(ceil(size.height / Self.cellSize))
            for row in 0..<rows {
                for col in 0..<cols {
                    let origin = CGPoint(x: CGFloat(col) * Self.cellSize, y: CGFloat(row) * Self.cellSize)
                    let flip = nextRandom() > 0.5
                    drawCell(context: context, origin: origin, flip: flip,
                             opacityA: 0.015 + nextRandom() * 0.025,
                             opacityB: 0.015 + nextRandom() * 0.025)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func drawCell(context: GraphicsContext, origin: CGPoint, flip: Bool,
                          opacityA: Double, opacityB: Double) {
        let cell = Self.cellSize
        let topLeading = origin
        let topTrailing = CGPoint(x: origin.x + cell, y: origin.y)
        let bottomLeading = CGPoint(x: origin.x, y: origin.y + cell)
        let bottomTrailing = CGPoint(x: origin.x + cell, y: origin.y + cell)
        let firstTriangle = flip
            ? [topLeading, topTrailing, bottomLeading]
            : [topLeading, topTrailing, bottomTrailing]
        let secondTriangle = flip
            ? [topTrailing, bottomTrailing, bottomLeading]
            : [topLeading, bottomTrailing, bottomLeading]
        context.fill(trianglePath(firstTriangle), with: .color(palette.border.opacity(opacityA)))
        context.fill(trianglePath(secondTriangle), with: .color(palette.border.opacity(opacityB)))
    }

    private func trianglePath(_ points: [CGPoint]) -> Path {
        var path = Path()
        path.move(to: points[0])
        path.addLine(to: points[1])
        path.addLine(to: points[2])
        path.closeSubpath()
        return path
    }
}
