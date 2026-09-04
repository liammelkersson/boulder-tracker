import SwiftUI
import SwiftData
import Combine

struct LiveSessionView: View {
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var modelContext
    @Environment(PhoneSyncCoordinator.self) private var syncCoordinator
    @Environment(SessionActivityPresenter.self) private var activityPresenter
    @Query(sort: \Session.startTime) private var allSessions: [Session]
    let session: Session
    let onEnded: (Session) -> Void

    @State private var showingQuickAdd = false
    @State private var currentDate = Date.now

    private let clockTick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        // A sync race can delete the session mid-presentation; the final body
        // evaluation after that must not touch persisted properties.
        if session.isInvalidated {
            Color.clear
        } else {
            liveContent
        }
    }

    private var liveContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                timerHeader
                LiveGradeTally(problems: session.problems)
                    .padding(.top, 22)
                FlashGoalCard(session: session, recentSessions: finishedSessions)
                QuickLogRow(session: session)
                    .padding(.top, 24)
                problemsSection
                    .padding(.top, 26)
                SuggestedProblemsRow(
                    session: session,
                    allSessions: allSessions.persisted.withoutSampleData
                )
                    .padding(.top, 22)
                actionButtons
                    .padding(.top, 28)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .onReceive(clockTick) { now in currentDate = now }
        .sheet(isPresented: $showingQuickAdd) { QuickAddProblemSheet(session: session) }
    }

    private var timerHeader: some View {
        VStack(spacing: 0) {
            SectionHeading(title: "Session Live")
                .kerning(1)
            Text(SessionDurationFormat.timerString(
                from: currentDate.timeIntervalSince(session.startTime)
            ))
            .scaledFont(size: 56, weight: .bold)
            .monospacedDigit()
            .foregroundStyle(palette.text)
            .padding(.top, 8)
            Text(sessionContextLabel)
                .scaledFont(size: 14)
                .foregroundStyle(palette.textDim)
                .padding(.top, 6)
        }
        .padding(.top, 40)
    }

    /// Ended sessions only: the live one is the thing being measured, and demo
    /// rows must not set a flash target.
    private var finishedSessions: [Session] {
        allSessions.persisted.withoutSampleData.filter { !$0.isLive }
    }

    private var sessionContextLabel: String {
        let gymName = session.gym?.name ?? "Unknown gym"
        guard !session.partners.isEmpty else { return gymName }
        return "\(gymName) · \(session.partners.map(\.name).joined(separator: ", "))"
    }

    private var problemsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(title: "Problems")
            if session.problems.isEmpty {
                Text("No problems added yet")
                    .scaledFont(size: 14)
                    .foregroundStyle(palette.textFaint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            }
            ForEach(session.problems) { problem in
                ProblemTile(problem: problem)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                showingQuickAdd = true
            } label: {
                AccentButtonLabel(title: "+ New Problem")
            }
            .buttonStyle(.plain)
            Button(action: endSession) {
                SecondaryButtonLabel(title: "End Session", titleColor: ThemePalette.danger)
            }
            .buttonStyle(.plain)
        }
    }

    private func endSession() {
        session.endTime = .now
        modelContext.saveReportingFailure(operation: "session end")
        syncCoordinator.announceEnd(of: session)
        activityPresenter.end(for: session)
        onEnded(session)
    }
}

struct LiveGradeTally: View {
    @Environment(\.palette) private var palette
    @Environment(\.gradeSystem) private var gradeSystem
    let problems: [SessionProblem]

    private var tally: [(grade: ColorGrade, count: Int)] {
        ColorGrade.displayOrder.compactMap { grade in
            let count = problems
                .filter { $0.colorGrade == grade }
                .reduce(0) { $0 + $1.totalLogs }
            return count > 0 ? (grade, count) : nil
        }
    }

    var body: some View {
        if !tally.isEmpty {
            HStack(spacing: 8) {
                ForEach(tally, id: \.grade) { entry in
                    HStack(spacing: 7) {
                        GradeDot(grade: entry.grade)
                        Text(entry.grade.shortLabel(in: gradeSystem))
                            .scaledFont(size: 13, weight: .medium)
                            .foregroundStyle(palette.text)
                        Text("\(entry.count)")
                            .scaledFont(size: 13, weight: .semibold)
                            .foregroundStyle(palette.textFaint)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .themedCard(cornerRadius: 100)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}
