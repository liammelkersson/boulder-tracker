import SwiftUI

/// A climbing-hold blob in the grade's color with the little bolt in the middle,
/// as drawn on problem tiles and achievement cards in the mockup.
struct HoldIcon: View {
    @Environment(\.palette) private var palette
    let grade: ColorGrade
    var size: CGFloat = 34
    var baseColorOverride: Color?

    private var baseColor: Color { baseColorOverride ?? grade.displayColor }

    var body: some View {
        ZStack {
            grade.holdShape
                .fill(baseColor)
                .overlay {
                    grade.holdShape
                        .fill(
                            LinearGradient(
                                colors: [palette.border.opacity(0.28), .clear, .black.opacity(0.30)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    if grade.needsOutline {
                        grade.holdShape.stroke(palette.border.opacity(0.25), lineWidth: 1)
                    }
                }
                .rotationEffect(grade.holdRotation)
            boltDot
        }
        .frame(width: size, height: size)
    }

    private var boltDot: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color(hex: 0xFDFDFD), Color(hex: 0xC9C9CD), Color(hex: 0x9A9A9E)],
                    center: .init(x: 0.35, y: 0.30), startRadius: 0, endRadius: size * 0.12
                )
            )
            .frame(width: size * 0.19, height: size * 0.19)
            .overlay {
                Circle()
                    .fill(Color(hex: 0x222222))
                    .frame(width: size * 0.09, height: size * 0.09)
            }
    }
}
