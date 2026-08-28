import SwiftUI

struct RecentSessionsList: View {
    let sessions: [Session]
    private static let recentLimit = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent sessions").font(.headline)
            ForEach(sessions.prefix(Self.recentLimit)) { session in
                NavigationLink(value: session.persistentModelID) {
                    SessionRow(session: session)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct SessionRow: View {
    let session: Session

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(session.startTime, format: .dateTime.weekday(.wide).day().month())
                    .font(.subheadline.bold())
                Text(session.gym?.name ?? "Unknown gym")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(session.attempts.filter { $0.result.countsAsSend }.count) sends")
                .font(.caption.bold())
        }
        .padding(.vertical, 8)
    }
}
