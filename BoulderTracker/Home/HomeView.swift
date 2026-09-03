import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: \Session.startTime, order: .reverse) private var sessions: [Session]
    @State private var summarySession: Session?

    private var liveSession: Session? { sessions.first { $0.isLive } }
    private var finishedSessions: [Session] {
        sessions.withoutSampleData.filter { !$0.isLive }
    }

    var body: some View {
        Group {
            if let summarySession {
                SessionSummaryScreen(session: summarySession) {
                    self.summarySession = nil
                }
            } else if let liveSession {
                LiveSessionView(session: liveSession) { ended in
                    summarySession = ended
                }
            } else {
                // Starting a session lives on the Start tab.
                HomeIdleView(sessions: finishedSessions)
            }
        }
    }
}
