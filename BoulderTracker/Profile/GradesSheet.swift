import SwiftUI

struct GradesSheet: View {
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Grades")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(palette.text)
            VStack(spacing: 0) {
                ForEach(ColorGrade.displayOrder) { grade in
                    gradeRow(grade)
                }
            }
            .themedCard(sunken: true)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 26)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func gradeRow(_ grade: ColorGrade) -> some View {
        HStack(spacing: 10) {
            GradeDot(grade: grade, size: 14)
            Text(grade.displayName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.text)
                .frame(width: 64, alignment: .leading)
            Text("V-scale \(grade.vGradeRange)")
                .font(.system(size: 13))
                .foregroundStyle(palette.textDim)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Font \(grade.frenchRange)")
                .font(.system(size: 13))
                .foregroundStyle(palette.textDim)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(palette.border.opacity(0.08)).frame(height: 0.5)
        }
    }
}
