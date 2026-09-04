import Testing
import Foundation
@testable import BoulderTracker

@MainActor
struct StatsAggregatorTests {
    private let calendar = Calendar(identifier: .iso8601)

    private func makeSession(daysAgo: Int, durationMinutes: Int = 90,
                             referenceDate: Date = .now) -> Session {
        let start = calendar.date(byAdding: .day, value: -daysAgo, to: referenceDate)!
        let session = Session(startTime: start, gym: nil, partners: [])
        session.endTime = start.addingTimeInterval(TimeInterval(durationMinutes * 60))
        return session
    }

    @discardableResult
    private func addProblem(_ session: Session, grade: ColorGrade,
                            styles: [RouteStyle] = [], flashes: Int = 0,
                            sends: Int = 0, falls: Int = 0) -> SessionProblem {
        let problem = SessionProblem(
            name: "Problem \(session.problems.count + 1)", colorGrade: grade, styles: styles,
            flashCount: flashes, sendCount: sends, fallCount: falls
        )
        session.problems.append(problem)
        return problem
    }

    @Test func summaryCountsSendsFlashesAndRates() {
        let session = makeSession(daysAgo: 0)
        addProblem(session, grade: .green, flashes: 1)
        addProblem(session, grade: .blue, sends: 1, falls: 2)
        addProblem(session, grade: .red, falls: 5)

        let summary = StatsAggregator.summary(of: [session])

        #expect(summary.problemCount == 3)
        #expect(summary.sendCount == 2)
        #expect(summary.flashCount == 1)
        #expect(summary.attemptCount == 9)
        #expect(abs(summary.completionRate - 2.0 / 9.0) < 0.001)
        #expect(abs(summary.flashRate - 1.0 / 9.0) < 0.001)
    }

    @Test func quickLogRepeatsCountEverySendAndFlash() {
        let session = makeSession(daysAgo: 0)
        addProblem(session, grade: .green, flashes: 3, sends: 5, falls: 2)

        let summary = StatsAggregator.summary(of: [session])
        let perGrade = StatsAggregator.sendCountPerGrade(of: [session])

        #expect(summary.sendCount == 8)
        #expect(summary.flashCount == 3)
        #expect(perGrade[.green] == 8)
    }

    @Test func emptySummaryHasZeroRates() {
        let summary = StatsAggregator.summary(of: [])
        #expect(summary.completionRate == 0)
        #expect(summary.flashRate == 0)
    }

    @Test func periodFilterExcludesOldSessions() {
        let recent = makeSession(daysAgo: 5)
        let old = makeSession(daysAgo: 400)
        let interval = StatsPeriod.threeMonths.interval(endingAt: .now, calendar: calendar)

        let filtered = StatsAggregator.sessions([recent, old], in: interval)

        #expect(filtered.count == 1)
    }

    @Test func allPeriodHasNilInterval() {
        #expect(StatsPeriod.all.interval(endingAt: .now, calendar: calendar) == nil)
    }

    @Test func climbingDaysCountsUniqueDays() {
        let morning = makeSession(daysAgo: 1)
        let evening = makeSession(daysAgo: 1)
        let other = makeSession(daysAgo: 3)

        let dayCount = StatsAggregator.climbingDayCount(
            of: [morning, evening, other], calendar: calendar
        )

        #expect(dayCount == 2)
    }

    @Test func sendCountPerGradeIgnoresUnsentProblems() {
        let session = makeSession(daysAgo: 0)
        addProblem(session, grade: .blue, flashes: 1)
        addProblem(session, grade: .blue, sends: 1)
        addProblem(session, grade: .blue, falls: 3)

        let counts = StatsAggregator.sendCountPerGrade(of: [session])

        #expect(counts[.blue] == 2)
        #expect(counts[.red] == nil)
    }

    @Test func hardestSendPicksHighestGrade() {
        let session = makeSession(daysAgo: 0)
        addProblem(session, grade: .black, sends: 1)
        addProblem(session, grade: .white, falls: 4)
        addProblem(session, grade: .red, flashes: 1)

        let hardest = StatsAggregator.hardestSend(of: [session])

        #expect(hardest?.colorGrade == .black)
    }

    @Test func proudestSendBreaksTiesByLogCount() {
        let session = makeSession(daysAgo: 0)
        addProblem(session, grade: .black, sends: 1, falls: 1)
        addProblem(session, grade: .black, sends: 1, falls: 8)

        let proudest = StatsAggregator.proudestSend(of: [session])

        #expect(proudest?.totalLogs == 9)
    }

    @Test func sendRatePerStyleComputesPerStyleRatio() {
        let session = makeSession(daysAgo: 0)
        addProblem(session, grade: .red, styles: [.sloper], sends: 1)
        addProblem(session, grade: .red, styles: [.sloper], falls: 2)
        addProblem(session, grade: .red, styles: [.crimp], flashes: 1)

        let rates = StatsAggregator.sendRatePerStyle(of: [session])

        #expect(abs((rates[.sloper] ?? 0) - 0.5) < 0.001)
        #expect(abs((rates[.crimp] ?? 0) - 1.0) < 0.001)
    }

    @Test func proudestSendBreaksFullTieByLatestSessionDate() {
        let referenceDate = Date.now
        let earlierSession = makeSession(daysAgo: 10, referenceDate: referenceDate)
        let laterSession = makeSession(daysAgo: 1, referenceDate: referenceDate)
        addProblem(earlierSession, grade: .black, sends: 1, falls: 2)
        addProblem(laterSession, grade: .black, sends: 1, falls: 2)

        let proudest = StatsAggregator.proudestSend(of: [earlierSession, laterSession])

        #expect(proudest?.session === laterSession)
    }

    @Test func weeklyStreakCountsConsecutiveWeeks() {
        let referenceDate = Date.now
        let thisWeek = makeSession(daysAgo: 0, referenceDate: referenceDate)
        let lastWeek = makeSession(daysAgo: 7, referenceDate: referenceDate)
        let threeWeeksAgo = makeSession(daysAgo: 21, referenceDate: referenceDate)

        let streak = StatsAggregator.weeklyStreak(
            of: [thisWeek, lastWeek, threeWeeksAgo],
            calendar: calendar, referenceDate: referenceDate
        )

        #expect(streak == 2)
    }
}
