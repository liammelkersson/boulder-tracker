import SwiftUI

/// Mountain silhouette for outdoor artwork: a sharp main summit, a lower
/// shoulder peak to its right, and a flat base. Ridges are straight lines so
/// the summit stays crisp, unlike the smooth plastic blobs of `HoldBlobShape`.
struct MountainShape: Shape {
    /// Normalized outline, left to right: base, left flank, summit, saddle,
    /// shoulder peak, right flank, base.
    private static let outline: [CGPoint] = [
        CGPoint(x: 0.02, y: 0.94),
        CGPoint(x: 0.23, y: 0.47),
        CGPoint(x: 0.33, y: 0.24),
        CGPoint(x: 0.42, y: 0.05),
        CGPoint(x: 0.51, y: 0.27),
        CGPoint(x: 0.59, y: 0.51),
        CGPoint(x: 0.71, y: 0.33),
        CGPoint(x: 0.85, y: 0.67),
        CGPoint(x: 0.98, y: 0.94),
    ]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let points = Self.outline.map { vertex in
            CGPoint(
                x: rect.minX + vertex.x * rect.width,
                y: rect.minY + vertex.y * rect.height
            )
        }
        path.move(to: points[0])
        for vertex in points.dropFirst() {
            path.addLine(to: vertex)
        }
        path.closeSubpath()
        return path
    }
}
