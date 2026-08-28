import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: \Session.startTime, order: .reverse) private var sessions: [Session]
    @State private var showingStartSheet = false
    @State private var showingRetroForm = false

    private var liveSession: Session? { sessions.first { $0.isLive } }
    private var finishedSessions: [Session] { sessions.filter { !$0.isLive } }
    private var overviewSessions: [Session] {
        let interval = StatsPeriod.threeMonths.interval(endingAt: .now, calendar: .current)
        return StatsAggregator.sessions(finishedSessions, in: interval)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let liveSession {
                    LiveSessionView(session: liveSession)
                } else {
                    overviewContent
                }
            }
            .navigationTitle("Boulder Tracker")
            .navigationDestination(for: PersistentIdentifier.self) { sessionID in
                SessionDetailView(sessionID: sessionID)
            }
        }
    }

    private var overviewContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                OverviewSection(sessions: overviewSessions)
                HighlightCard(sessions: overviewSessions)
                startButtons
                RecentSessionsList(sessions: finishedSessions)
            }
            .padding()
        }
        .sheet(isPresented: $showingStartSheet) { StartSessionSheet() }
        .sheet(isPresented: $showingRetroForm) { RetroSessionForm() }
    }

    private var startButtons: some View {
        VStack(spacing: 12) {
            Button {
                showingStartSheet = true
            } label: {
                Label("Start Session", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.glassProminent)
            .tint(.accentColor)

            Button("Add Past Session") { showingRetroForm = true }
                .buttonStyle(.glass)
        }
    }
}
