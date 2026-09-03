import SwiftUI

/// Outdoor counterpart to `HoldIcon`: a rock silhouette with the same
/// lighting treatment but no bolt — real rock is not bolted to a wall.
struct MountainIcon: View {
    @Environment(\.palette) private var palette
    var size: CGFloat = 34
    var baseColorOverride: Color?

    /// Granite grey used when no achievement color is supplied.
    private static let graniteColor = Color(hex: 0x8A8578)

    private var baseColor: Color { baseColorOverride ?? Self.graniteColor }

    var body: some View {
        MountainShape()
            .fill(baseColor)
            .overlay {
                MountainShape()
                    .fill(
                        LinearGradient(
                            colors: [palette.border.opacity(0.28), .clear, .black.opacity(0.30)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                MountainShape().stroke(palette.border.opacity(0.25), lineWidth: 1)
            }
            .frame(width: size, height: size)
    }
}
