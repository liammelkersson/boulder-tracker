import SwiftUI
import SwiftData

struct ActivitiesView: View {
    @Environment(\.palette) private var palette
    @Query(sort: \Session.startTime, order: .reverse) private var sessions: [Session]

    @State private var displayedMonth = Date.now
    @State private var selectedDay: Date?
    @State private var detailSession: Session?

    private var finishedSessions: [Session] { sessions.persisted.filter { !$0.isLive } }

    private var listedSessions: [Session] {
        guard let selectedDay else { return finishedSessions }
        let calendar = Calendar.current
        return finishedSessions.filter { calendar.isDate($0.startTime, inSameDayAs: selectedDay) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                MonthCalendarGrid(
                    month: displayedMonth,
                    sessions: finishedSessions,
                    selectedDay: $selectedDay
                )
                .padding(.top, 22)
                sessionList
                    .padding(.top, 28)
            }
            .padding(.horizontal, 20)
            .padding(.top, 40)
            .padding(.bottom, 24)
        }
        .sheet(item: $detailSession) { session in
            SessionDetailSheet(session: session)
        }
    }

    private var monthSessions: [Session] {
        let calendar = Calendar.current
        return finishedSessions.filter {
            calendar.isDate($0.startTime, equalTo: displayedMonth, toGranularity: .month)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 0) {
                Text(displayedMonth, format: .dateTime.month(.wide).year())
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(palette.text)
                Text("Hours on Wall")
                    .font(.system(size: 14))
                    .foregroundStyle(palette.textDim)
                    .padding(.top, 14)
                Text(SessionDurationFormat.compactString(
                    from: monthSessions.reduce(0) { $0 + $1.duration }
                ))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(palette.text)
                .padding(.top, 2)
            }
            Spacer()
            monthStepButton(systemName: "chevron.left", monthDelta: -1)
            monthStepButton(systemName: "chevron.right", monthDelta: 1)
        }
    }

    private func monthStepButton(systemName: String, monthDelta: Int) -> some View {
        Button {
            if let shifted = Calendar.current.date(
                byAdding: .month, value: monthDelta, to: displayedMonth
            ) {
                displayedMonth = shifted
                selectedDay = nil
            }
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.textDim)
                .frame(width: 32, height: 32)
                .background(palette.surface)
                .clipShape(.circle)
        }
        .buttonStyle(.plain)
    }

    private var sessionList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(selectedDay == nil ? "All Sessions" : "Sessions that day")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(palette.text)
            if listedSessions.isEmpty {
                Text("No sessions logged")
                    .font(.system(size: 14))
                    .foregroundStyle(palette.textFaint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            }
            ForEach(listedSessions) { session in
                Button {
                    detailSession = session
                } label: {
                    SessionRowCard(session: session, showsGymInSummary: true)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
