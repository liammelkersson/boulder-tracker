import Foundation

/// The guide's "pick three boulders at 70% of your max" expressed in colour
/// bands: one band below the hardest band sent recently, three flashes deep.
struct FlashGoal: Equatable {
    static let flashCount = 3

    /// How far back a send still counts towards the working band. A peak from
    /// last season says little about what flashes tonight.
    private static let windowDays = 90

    let band: ColorGrade
    let flashesLogged: Int

    /// Fails when no send inside the window sets a working band: without one
    /// there is no honest target to suggest.
    init?(recentSessions: [Session], liveSession: Session,
          referenceDate: Date = .now, calendar: Calendar = .current) {
        guard let windowStart = calendar.date(
            byAdding: .day, value: -Self.windowDays, to: referenceDate
        ) else { return nil }
        let recent = recentSessions.filter { $0.startTime >= windowStart }
        let sentCounts = StatsAggregator.sentProblemCountPerGrade(of: recent)
        guard let workingBand = ColorGrade.ladder.last(where: { (sentCounts[$0] ?? 0) > 0 })
        else { return nil }
        let targetBand = workingBand.easierBand ?? workingBand
        band = targetBand
        flashesLogged = liveSession.problems
            .filter { $0.colorGrade == targetBand }
            .reduce(0) { $0 + $1.flashCount }
    }

    var isMet: Bool { flashesLogged >= Self.flashCount }

    var remainingCount: Int { max(0, Self.flashCount - flashesLogged) }
}
