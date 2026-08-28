import SwiftUI

struct OverviewSection: View {
    let sessions: [Session]

    private var summary: StatsSummary { StatsAggregator.summary(of: sessions) }
    private var climbingDays: Int {
        StatsAggregator.climbingDayCount(of: sessions, calendar: .current)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            greeting
            totalTimeCard
            metricRow
        }
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Liam,")
                .font(.largeTitle.bold())
                .foregroundStyle(Color.accentColor)
            Text("\(climbingDays) climbing days in the last 3 months")
                .font(.headline)
        }
    }

    private var totalTimeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Total climb time", systemImage: "stopwatch")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(SessionDurationFormat.string(from: summary.totalDuration))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .glassEffect(in: .rect(cornerRadius: 20))
    }

    private var metricRow: some View {
        HStack {
            MetricTile(label: "Sent", valueText: "\(summary.sendCount)")
            MetricTile(label: "Attempts", valueText: "\(summary.attemptCount)")
            MetricTile(
                label: "Completion",
                valueText: summary.completionRate.formatted(.percent.precision(.fractionLength(0)))
            )
        }
    }
}

struct MetricTile: View {
    let label: String
    let valueText: String

    var body: some View {
        VStack(spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(valueText).font(.title2.bold()).monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .glassEffect(in: .rect(cornerRadius: 16))
    }
}
