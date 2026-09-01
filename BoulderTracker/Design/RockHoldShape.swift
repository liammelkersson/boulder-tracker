import SwiftUI

/// Faceted boulder silhouette for outdoor artwork: an irregular polygon with
/// softened vertices, unlike the smooth plastic blobs of `HoldBlobShape`.
struct RockHoldShape: Shape {
    /// Normalized outline vertices, clockwise from the left face.
    private static let vertices: [CGPoint] = [
        CGPoint(x: 0.10, y: 0.66),
        CGPoint(x: 0.20, y: 0.28),
        CGPoint(x: 0.46, y: 0.06),
        CGPoint(x: 0.74, y: 0.14),
        CGPoint(x: 0.94, y: 0.42),
        CGPoint(x: 0.90, y: 0.78),
        CGPoint(x: 0.66, y: 0.96),
        CGPoint(x: 0.24, y: 0.92),
    ]

    func path(in rect: CGRect) -> Path {
        let points = Self.vertices.map { vertex in
            CGPoint(
                x: rect.minX + vertex.x * rect.width,
                y: rect.minY + vertex.y * rect.height
            )
        }
        var path = Path()
        // Trace edge midpoints with each vertex as curve control, so every
        // facet corner stays visible but slightly weathered.
        path.move(to: midpoint(points[points.count - 1], points[0]))
        for (index, vertex) in points.enumerated() {
            let next = points[(index + 1) % points.count]
            path.addQuadCurve(to: midpoint(vertex, next), control: vertex)
        }
        path.closeSubpath()
        return path
    }

    private func midpoint(_ first: CGPoint, _ second: CGPoint) -> CGPoint {
        CGPoint(x: (first.x + second.x) / 2, y: (first.y + second.y) / 2)
    }
}
