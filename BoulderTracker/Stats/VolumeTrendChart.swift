import SwiftUI
import Charts

/// Grouped weekly bars of problems logged vs. sends, like a step-count card.
struct VolumeTrendChart: View {
    @Environment(\.palette) private var palette
    let sessions: [Session]

    private static let chartHeight: CGFloat = 170

    private struct WeeklyMetricBar: Identifiable {
        let id: String
        let weekStart: Date
        let metric: String
        let count: Int
    }

    private static let problemsMetric = "Problems"
    private static let sendsMetric = "Sends"

    private var bars: [WeeklyMetricBar] {
        StatsAggregator.weeklyVolume(of: sessions.persisted, calendar: .current).flatMap { volume in
            [
                WeeklyMetricBar(
                    id: "\(volume.weekStart)-problems", weekStart: volume.weekStart,
                    metric: Self.problemsMetric, count: volume.problemCount
                ),
                WeeklyMetricBar(
                    id: "\(volume.weekStart)-sends", weekStart: volume.weekStart,
                    metric: Self.sendsMetric, count: volume.sendCount
                ),
            ]
        }
    }

    var body: some View {
        let bars = self.bars
        if !bars.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeading(title: "Weekly volume")
                chart(bars)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .themedCard(cornerRadius: 20)
            }
        }
    }

    private func chart(_ bars: [WeeklyMetricBar]) -> some View {
        Chart(bars) { bar in
            BarMark(
                x: .value("Week", bar.weekStart, unit: .weekOfYear),
                y: .value("Count", bar.count)
            )
            .position(by: .value("Metric", bar.metric))
            .foregroundStyle(by: .value("Metric", bar.metric))
            .cornerRadius(3)
        }
        .chartForegroundStyleScale([
            Self.problemsMetric: AnyShapeStyle(palette.textFaint.opacity(0.45)),
            Self.sendsMetric: AnyShapeStyle(ThemePalette.accent),
        ])
        .chartLegend(position: .top, alignment: .leading, spacing: 8)
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine().foregroundStyle(palette.border.opacity(0.1))
                AxisValueLabel()
                    .foregroundStyle(palette.textFaint)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .foregroundStyle(palette.textFaint)
            }
        }
        .frame(height: Self.chartHeight)
    }
}
