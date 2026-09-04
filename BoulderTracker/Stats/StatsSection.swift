import SwiftUI
import SwiftData

/// The stats body: period picker, summary tiles, charts, personal bests. Owns
/// its own period selection so any screen can drop it in.
struct StatsSection: View {
    @Environment(\.palette) private var palette
    @Query(sort: \Session.startTime, order: .reverse) private var sessions: [Session]
    @State private var period: StatsPeriod = .threeMonths

    private var periodSessions: [Session] {
        let finished = sessions.persisted.filter { !$0.isLive }
        let interval = period.interval(endingAt: .now, calendar: .current)
        return StatsAggregator.sessions(finished, in: interval)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            periodSelector
            summaryGrid
            GradeProgressionChart(sessions: periodSessions)
            VolumeTrendChart(sessions: periodSessions)
            GradeDistributionCard(sessions: periodSessions)
            PyramidCard(sessions: periodSessions)
            StyleRadialChart(sessions: periodSessions)
            SkillCoverageCard(sessions: periodSessions)
            PersonalBestsSection(sessions: periodSessions)
            SampleDataToggleRow()
        }
    }

    private var periodSelector: some View {
        HStack(spacing: 6) {
            ForEach(StatsPeriod.allCases) { option in
                periodPill(option)
            }
        }
        .padding(.top, -12)
    }

    private func periodPill(_ option: StatsPeriod) -> some View {
        let isSelected = period == option
        return Button {
            period = option
        } label: {
            Text(option.displayName)
                .scaledFont(size: 13, weight: .semibold)
                .foregroundStyle(isSelected ? ThemePalette.onAccent : palette.textDim)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isSelected ? ThemePalette.accent : palette.surface)
                .clipShape(.rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private var summaryGrid: some View {
        let summary = StatsAggregator.summary(of: periodSessions)
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            StatTile(valueText: "\(summary.sessionCount)", label: "Sessions")
            StatTile(
                valueText: SessionDurationFormat.compactString(from: summary.totalDuration),
                label: "Total time"
            )
            StatTile(valueText: "\(summary.problemCount)", label: "Problems")
            StatTile(valueText: "\(summary.sendCount)", label: "Sends")
            StatTile(
                valueText: summary.flashRate.formatted(.percent.precision(.fractionLength(0))),
                label: "Flash rate"
            )
        }
    }
}
