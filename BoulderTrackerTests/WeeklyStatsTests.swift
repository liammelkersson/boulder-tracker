import Testing
import Foundation
@testable import BoulderTracker

@MainActor
struct WeeklyStatsTests {
    private let calendar = Calendar(identifier: .iso8601)
    /// Fixed mid-week date (a Wednesday) so week boundaries never flake.
    private let referenceDate = ISO8601DateFormatter().date(from: "2026-08-26T12:00:00Z")!

    private func makeSession(daysAgo: Int) -> Session {
        let start = calendar.date(byAdding: .day, value: -daysAgo, to: referenceDate)!
        let session = Session(startTime: start, gym: nil, partners: [])
        session.endTime = start.addingTimeInterval(3600)
        return session
    }

    private func addProblem(_ session: Session, grade: ColorGrade,
                            flashes: Int = 0, sends: Int = 0, falls: Int = 0) {
        session.problems.append(SessionProblem(
            name: "Problem", colorGrade: grade, styles: [],
            flashCount: flashes, sendCount: sends, fallCount: falls
        ))
    }

    @Test func weeklyVolumeGroupsSessionsByWeek() {
        let wednesday = makeSession(daysAgo: 0)
        let tuesday = makeSession(daysAgo: 1)
        let twoWeeksBack = makeSession(daysAgo: 14)
        addProblem(wednesday, grade: .blue, sends: 1)
        addProblem(tuesday, grade: .green, flashes: 1, falls: 2)
        addProblem(twoWeeksBack, grade: .red, falls: 3)

        let volumes = StatsAggregator.weeklyVolume(
            of: [wednesday, tuesday, twoWeeksBack], calendar: calendar
        )

        #expect(volumes.count == 2)
        #expect(volumes.first!.weekStart < volumes.last!.weekStart)
        #expect(volumes.last?.problemCount == 2)
        #expect(volumes.last?.sendCount == 2)
        #expect(volumes.first?.problemCount == 1)
        #expect(volumes.first?.sendCount == 0)
    }

    @Test func weeklyVolumeOfNoSessionsIsEmpty() {
        #expect(StatsAggregator.weeklyVolume(of: [], calendar: calendar).isEmpty)
    }

    @Test func hardestSendPerWeekPicksMaxSentGrade() {
        let thisWeek = makeSession(daysAgo: 0)
        let twoWeeksBack = makeSession(daysAgo: 14)
        addProblem(thisWeek, grade: .blue, sends: 1)
        addProblem(thisWeek, grade: .white, falls: 5)
        addProblem(twoWeeksBack, grade: .black, flashes: 1)

        let points = StatsAggregator.hardestSendPerWeek(
            of: [thisWeek, twoWeeksBack], calendar: calendar
        )

        #expect(points.count == 2)
        #expect(points.first?.grade == .black)
        #expect(points.last?.grade == .blue)
        #expect(points.first!.weekStart < points.last!.weekStart)
    }

    @Test func hardestSendPerWeekSkipsWeeksWithoutSends() {
        let fallsOnly = makeSession(daysAgo: 0)
        addProblem(fallsOnly, grade: .red, falls: 4)

        #expect(StatsAggregator.hardestSendPerWeek(of: [fallsOnly], calendar: calendar).isEmpty)
    }
}
