import SwiftUI

/// Tonight's flash goal: three at one band below what you have been sending.
/// Hidden until there is a recent send to base the band on.
struct FlashGoalCard: View {
    @Environment(\.palette) private var palette
    @Environment(\.gradeSystem) private var gradeSystem
    let session: Session
    let recentSessions: [Session]

    private var goal: FlashGoal? {
        FlashGoal(recentSessions: recentSessions, liveSession: session)
    }

    var body: some View {
        if let goal {
            card(goal)
        }
    }

    private func card(_ goal: FlashGoal) -> some View {
        HStack(spacing: 12) {
            GradeDot(grade: goal.band)
            VStack(alignment: .leading, spacing: 2) {
                Text("Flash goal · \(goal.band.shortLabel(in: gradeSystem))")
                    .scaledFont(size: 14, weight: .semibold)
                    .foregroundStyle(palette.text)
                Text(subtitle(goal))
                    .scaledFont(size: 12)
                    .foregroundStyle(palette.textDim)
            }
            Spacer()
            Text("\(goal.flashesLogged)/\(FlashGoal.flashCount)")
                .scaledFont(size: 14, weight: .semibold)
                .monospacedDigit()
                .foregroundStyle(goal.isMet ? ThemePalette.onAccent : palette.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(goal.isMet ? ThemePalette.accent : palette.pill)
                .clipShape(.capsule)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard(cornerRadius: 18)
        // Owned here rather than by the caller: an absent goal renders nothing,
        // and spacing applied outside would leave a gap where the card is not.
        .padding(.top, 20)
    }

    private func subtitle(_ goal: FlashGoal) -> String {
        guard !goal.isMet else { return "Goal met — read, commit, climb" }
        return goal.remainingCount == 1
            ? "1 flash to go"
            : "\(goal.remainingCount) flashes to go"
    }
}
