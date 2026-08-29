import SwiftUI

struct HomeMetricsRow: View {
    let sessions: [Session]

    private var summary: StatsSummary { StatsAggregator.summary(of: sessions) }

    var body: some View {
        HStack(spacing: 8) {
            StatTile(valueText: "\(summary.sessionCount)", label: "Sessions")
            StatTile(valueText: "\(summary.problemCount)", label: "Problems")
            StatTile(
                valueText: summary.flashRate.formatted(.percent.precision(.fractionLength(0))),
                label: "Flash rate"
            )
        }
    }
}
