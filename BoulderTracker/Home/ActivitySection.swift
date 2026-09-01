import SwiftUI

struct ActivitySection: View {
    @Environment(\.palette) private var palette
    let sessions: [Session]

    private static let recentLimit = 5

    @State private var showingRetroForm = false
    @State private var detailSession: Session?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            ForEach(sessions.persisted.prefix(Self.recentLimit)) { session in
                Button {
                    detailSession = session
                } label: {
                    SessionRowCard(session: session)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 6)
        .sheet(isPresented: $showingRetroForm) { RetroSessionForm() }
        .sheet(item: $detailSession) { session in
            SessionDetailSheet(session: session)
        }
    }

    private var header: some View {
        HStack {
            Text("Activity")
                .scaledFont(size: 16, weight: .semibold)
                .foregroundStyle(palette.text)
            Spacer()
            Button {
                showingRetroForm = true
            } label: {
                Text("+ Add Past Session")
                    .scaledFont(size: 13, weight: .medium)
                    .foregroundStyle(palette.textDim)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .themedCard(cornerRadius: 100)
            }
            .buttonStyle(.plain)
        }
    }
}
