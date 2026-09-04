import Foundation

/// One row of the pyramid: how many distinct problems were sent at a band
/// against how many that band's tier calls for.
struct PyramidTier: Equatable, Identifiable {
    let grade: ColorGrade
    let sentCount: Int
    let target: Int

    var id: Int { grade.rawValue }

    var isMet: Bool { sentCount >= target }

    var shortfall: Int { max(0, target - sentCount) }
}

/// The guide's climbing pyramid: a wide base of easier sends tapering to a
/// handful at the top, one tier doubling into the next. Its opposite — one send
/// per band on the way up — is the totem pole.
struct GradePyramid: Equatable {
    /// Targets from the top tier downward.
    private static let tierTargets = [1, 2, 4, 8]

    /// Top tier first, so the pyramid reads apex-to-base.
    let tiers: [PyramidTier]

    init(sessions: [Session]) {
        let sentCounts = StatsAggregator.sentProblemCountPerGrade(of: sessions)
        guard let topIndex = ColorGrade.ladder.lastIndex(where: { (sentCounts[$0] ?? 0) > 0 })
        else {
            tiers = []
            return
        }
        tiers = Self.tierTargets.indices.compactMap { offset in
            let bandIndex = topIndex - offset
            guard bandIndex >= 0 else { return nil }
            let grade = ColorGrade.ladder[bandIndex]
            return PyramidTier(
                grade: grade, sentCount: sentCounts[grade] ?? 0,
                target: Self.tierTargets[offset]
            )
        }
    }

    var isBalanced: Bool { tiers.allSatisfy(\.isMet) }

    /// Tiers below the apex that still owe sends, base-first is not needed:
    /// they stay in apex-to-base order so messages read top-down.
    var unmetTiers: [PyramidTier] { tiers.dropFirst().filter { !$0.isMet } }

    /// Grades pushed without the mileage underneath them. The apex is met by
    /// construction — it is the hardest band with a send, against a target of
    /// one — so an unbalanced pyramid is always one standing on a thin base.
    var isTotemPole: Bool { !tiers.isEmpty && !isBalanced }

    /// The band above the apex, which a balanced pyramid has earned a look at.
    var nextBand: ColorGrade? { tiers.first?.grade.harderBand }
}
