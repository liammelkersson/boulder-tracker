import Foundation

/// How many problems carried one skill over a period.
struct SkillTally: Equatable, Identifiable {
    let skill: MovementSkill
    let taggedCount: Int

    var id: String { skill.rawValue }
}

/// Which fundamentals a period actually practised. The guide asks for the
/// weakest skill, which needs the neglected ones counted, not just the used ones.
enum MovementSkillCoverage {
    /// Every skill, in declaration order, so the card's rows never reorder
    /// underneath the reader as counts change.
    static func tallies(of sessions: [Session]) -> [SkillTally] {
        let counts = taggedCounts(in: sessions)
        return MovementSkill.allCases.map { skill in
            SkillTally(skill: skill, taggedCount: counts[skill] ?? 0)
        }
    }

    /// The least-tagged skill, or `nil` while nothing has been tagged at all —
    /// with no tags, no skill is weaker than another. Ties go to declaration
    /// order.
    static func weakestSkill(of sessions: [Session]) -> MovementSkill? {
        let counts = taggedCounts(in: sessions)
        guard !counts.isEmpty else { return nil }
        return tallies(of: sessions).min { $0.taggedCount < $1.taggedCount }?.skill
    }

    private static func taggedCounts(in sessions: [Session]) -> [MovementSkill: Int] {
        var counts: [MovementSkill: Int] = [:]
        for problem in sessions.flatMap(\.problems) {
            for skill in problem.skills {
                counts[skill, default: 0] += 1
            }
        }
        return counts
    }
}
