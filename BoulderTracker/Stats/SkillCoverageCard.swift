import SwiftUI

/// Which fundamentals the period practised, and which one has been neglected.
struct SkillCoverageCard: View {
    @Environment(\.palette) private var palette
    let sessions: [Session]

    private var tallies: [SkillTally] {
        MovementSkillCoverage.tallies(of: sessions.persisted)
    }

    private var weakestSkill: MovementSkill? {
        MovementSkillCoverage.weakestSkill(of: sessions.persisted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Fundamentals")
            VStack(alignment: .leading, spacing: 12) {
                if let weakestSkill {
                    ForEach(tallies) { tally in
                        skillRow(tally, isWeakest: tally.skill == weakestSkill)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Least practised: \(weakestSkill.displayName)")
                            .scaledFont(size: 13)
                            .foregroundStyle(palette.textDim)
                        if let untaggedNote {
                            Text(untaggedNote)
                                .scaledFont(size: 12)
                                .foregroundStyle(palette.textFaint)
                        }
                    }
                    .padding(.top, 2)
                } else {
                    emptyState
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .themedCard(cornerRadius: 20)
        }
    }

    /// Names the missing data so a thin tally is not read as thin practice.
    /// Quick logs carry no tags, so most sessions leave some problems bare.
    private var untaggedNote: String? {
        let untaggedCount = MovementSkillCoverage.untaggedProblemCount(of: sessions.persisted)
        guard untaggedCount > 0 else { return nil }
        let problemCount = StatsAggregator.summary(of: sessions.persisted).problemCount
        return "\(untaggedCount) of \(problemCount) problems untagged"
    }

    private var emptyState: some View {
        Text("Tag fundamentals on a problem to see which ones you practise")
            .scaledFont(size: 14)
            .foregroundStyle(palette.textFaint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
    }

    private func skillRow(_ tally: SkillTally, isWeakest: Bool) -> some View {
        HStack(spacing: 10) {
            Text(tally.skill.displayName)
                .scaledFont(size: 14, weight: isWeakest ? .semibold : .regular)
                .foregroundStyle(isWeakest ? palette.text : palette.textDim)
            Spacer()
            Text(tally.taggedCount == 1 ? "1 problem" : "\(tally.taggedCount) problems")
                .scaledFont(size: 12, weight: .semibold)
                .monospacedDigit()
                .foregroundStyle(isWeakest ? palette.text : palette.textFaint)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isWeakest ? ThemePalette.accent.opacity(0.18) : palette.pill)
                .clipShape(.capsule)
        }
    }
}
