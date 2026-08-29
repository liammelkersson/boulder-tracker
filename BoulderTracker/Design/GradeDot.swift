import SwiftUI

struct GradeDot: View {
    @Environment(\.palette) private var palette
    let grade: ColorGrade
    var size: CGFloat = 10

    var body: some View {
        Circle()
            .fill(grade.displayColor)
            .overlay {
                if grade.needsOutline {
                    Circle().strokeBorder(palette.border.opacity(0.35), lineWidth: 1)
                }
            }
            .frame(width: size, height: size)
            .accessibilityLabel(grade.displayName)
    }
}
