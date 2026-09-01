import SwiftUI

/// Hold-colour swatch for watch rows. The phone's `GradeDot` depends on the phone
/// theme palette, so the watch draws its own against the fixed dark watch surface.
struct WatchGradeDot: View {
    let grade: ColorGrade

    private static let diameter: CGFloat = 12

    var body: some View {
        Circle()
            .fill(grade.displayColor)
            .overlay {
                if grade.needsOutline {
                    Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1)
                }
            }
            .frame(width: Self.diameter, height: Self.diameter)
            .accessibilityLabel(grade.displayName)
    }
}
