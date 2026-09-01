import SwiftUI
import Charts

/// Line chart of the hardest grade sent each week.
struct GradeProgressionChart: View {
    @Environment(\.palette) private var palette
    @Environment(\.gradeSystem) private var gradeSystem
    let sessions: [Session]

    private static let chartHeight: CGFloat = 190

    /// Ungraded sends sit outside the color scale, so they cannot be plotted.
    private var points: [WeeklyHardestSend] {
        StatsAggregator.hardestSendPerWeek(of: sessions.persisted, calendar: .current)
            .filter { $0.grade != .unknown }
    }

    var body: some View {
        let points = self.points
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Grade progression")
            Group {
                if points.isEmpty {
                    emptyState
                } else {
                    chart(points)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .themedCard(cornerRadius: 20)
        }
    }

    private var emptyState: some View {
        Text("No sends in this period yet")
            .scaledFont(size: 14)
            .foregroundStyle(palette.textFaint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
    }

    private func chart(_ points: [WeeklyHardestSend]) -> some View {
        Chart(points, id: \.weekStart) { point in
            LineMark(
                x: .value("Week", point.weekStart, unit: .weekOfYear),
                y: .value("Grade", point.grade.rawValue)
            )
            .foregroundStyle(ThemePalette.accent)
            .interpolationMethod(.monotone)
            .lineStyle(StrokeStyle(lineWidth: 2.5))
            PointMark(
                x: .value("Week", point.weekStart, unit: .weekOfYear),
                y: .value("Grade", point.grade.rawValue)
            )
            .foregroundStyle(point.grade.displayColor)
            .symbolSize(90)
        }
        .chartYScale(domain: ColorGrade.yellow.rawValue...ColorGrade.white.rawValue)
        .chartYAxis { gradeAxisMarks }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .foregroundStyle(palette.textFaint)
            }
        }
        .frame(height: Self.chartHeight)
    }

    private var gradeAxisMarks: some AxisContent {
        AxisMarks(values: ColorGrade.allCases.map(\.rawValue).filter { $0 >= 0 }) { value in
            AxisGridLine().foregroundStyle(palette.border.opacity(0.1))
            AxisValueLabel {
                if let gradeValue = value.as(Int.self),
                   let grade = ColorGrade(rawValue: gradeValue) {
                    Text(grade.shortLabel(in: gradeSystem))
                        .scaledFont(size: 10, weight: .semibold)
                        .foregroundStyle(palette.textDim)
                }
            }
        }
    }
}
