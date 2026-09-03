import SwiftUI

/// Wrapping row of selectable grade pills, shared by the problem and project
/// editors.
struct GradePicker: View {
    @Environment(\.palette) private var palette
    @Environment(\.gradeSystem) private var gradeSystem
    @Binding var selection: ColorGrade

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(ColorGrade.displayOrder) { grade in
                gradePill(grade)
            }
        }
    }

    private func gradePill(_ grade: ColorGrade) -> some View {
        let isSelected = selection == grade
        return Button {
            selection = grade
        } label: {
            HStack(spacing: 7) {
                GradeDot(grade: grade, size: 11)
                Text(grade.shortLabel(in: gradeSystem))
                    .scaledFont(size: 13, weight: .semibold)
                    .foregroundStyle(isSelected ? palette.text : palette.textDim)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(isSelected ? palette.pillActive : palette.pill)
            .clipShape(.capsule)
            .overlay {
                if isSelected {
                    Capsule().strokeBorder(ThemePalette.accent, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(grade.shortLabel(in: gradeSystem))
    }
}
