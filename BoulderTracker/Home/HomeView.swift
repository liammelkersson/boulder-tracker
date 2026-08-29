import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: \Session.startTime, order: .reverse) private var sessions: [Session]
    @State private var summarySession: Session?
    @State private var showingGymPicker = false

    private var liveSession: Session? { sessions.first { $0.isLive } }
    private var finishedSessions: [Session] { sessions.filter { !$0.isLive } }

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
                idleContent
            }
        }
    }

    private var idleContent: some View {
        HomeIdleView(sessions: finishedSessions)
            .overlay(alignment: .bottom) { startSessionButton }
            .sheet(isPresented: $showingGymPicker) { GymPickerSheet() }
    }

    private var startSessionButton: some View {
        Button {
            showingGymPicker = true
        } label: {
            AccentButtonLabel(title: "Start Session")
                .shadow(color: .black.opacity(0.35), radius: 12, y: 8)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}
