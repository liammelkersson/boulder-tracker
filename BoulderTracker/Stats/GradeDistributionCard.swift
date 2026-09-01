import SwiftUI

struct GradeDistributionCard: View {
    @Environment(\.palette) private var palette
    @Environment(\.gradeSystem) private var gradeSystem
    let sessions: [Session]

    private var sendCounts: [(grade: ColorGrade, count: Int)] {
        let counts = StatsAggregator.sendCountPerGrade(of: sessions.persisted)
        return ColorGrade.displayOrder.compactMap { grade in
            guard let count = counts[grade], count > 0 else { return nil }
            return (grade, count)
        }
    }

    private var totalSends: Int { sendCounts.reduce(0) { $0 + $1.count } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Sends by grade")
            VStack(alignment: .leading, spacing: 16) {
                if sendCounts.isEmpty {
                    Text("No sends in this period yet")
                        .font(.system(size: 14))
                        .foregroundStyle(palette.textFaint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                } else {
                    segmentBar
                    gradeRows
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .themedCard(cornerRadius: 20)
        }
    }

    private var segmentBar: some View {
        HStack(spacing: 3) {
            ForEach(sendCounts, id: \.grade) { entry in
                RoundedRectangle(cornerRadius: 8)
                    .fill(entry.grade.displayColor)
                    .frame(height: 30)
                    .frame(maxWidth: .infinity)
                    .layoutPriority(Double(entry.count))
                    .overlay {
                        if entry.grade.needsOutline {
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(palette.border.opacity(0.2), lineWidth: 1)
                        }
                    }
            }
        }
    }

    private var gradeRows: some View {
        VStack(spacing: 10) {
            ForEach(sendCounts, id: \.grade) { entry in
                gradeRow(entry.grade, count: entry.count)
            }
        }
    }

    private func gradeRow(_ grade: ColorGrade, count: Int) -> some View {
        let pct = totalSends == 0 ? 0 : Int((Double(count) / Double(totalSends) * 100).rounded())
        return HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(grade.displayColor)
                .frame(width: 3, height: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(grade.shortLabel(in: gradeSystem))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.text)
                Text(count == 1 ? "1 send" : "\(count) sends")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.textFaint)
            }
            Spacer()
            Text("\(pct)%")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.textDim)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(palette.pill)
                .clipShape(.capsule)
        }
    }
}
