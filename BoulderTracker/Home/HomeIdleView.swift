import SwiftUI

struct HomeIdleView: View {
    @Environment(\.palette) private var palette
    let sessions: [Session]

    private static let contentCornerRadius: CGFloat = 24

    private var recentPeriodSessions: [Session] {
        let interval = StatsPeriod.threeMonths.interval(endingAt: .now, calendar: .current)
        return StatsAggregator.sessions(sessions, in: interval)
    }

    var body: some View {
        ZStack(alignment: .top) {
            HomeBanner(sessions: recentPeriodSessions)
            ScrollView {
                VStack(spacing: 0) {
                    Color.clear.frame(height: HomeBanner.height - Self.contentCornerRadius)
                    scrolledContent
                }
            }
        }
        .ignoresSafeArea(edges: .top)
    }

    /// Opaque section that slides up over the fixed banner.
    private var scrolledContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            HeroTimeCard(sessions: recentPeriodSessions)
            CurrentProjectCard(sessions: sessions)
            HomeMetricsRow(sessions: recentPeriodSessions)
            ActivitySection(sessions: sessions)
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 96)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                palette.background
                WallTexture()
            }
        }
        .clipShape(.rect(
            topLeadingRadius: Self.contentCornerRadius,
            topTrailingRadius: Self.contentCornerRadius
        ))
    }
}
