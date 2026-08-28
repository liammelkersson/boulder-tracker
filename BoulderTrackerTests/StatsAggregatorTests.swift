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

    private func addAttempt(_ session: Session, grade: ColorGrade,
                            styles: [RouteStyle] = [], attempts: Int = 1,
                            result: AttemptResult) {
        let attempt = ProblemAttempt(colorGrade: grade, styles: styles,
                                     attemptCount: attempts, result: result)
        session.attempts.append(attempt)
    }

    @Test func summaryCountsSendsFlashesAndRates() {
        let session = makeSession(daysAgo: 0)
        addAttempt(session, grade: .green, result: .flash)
        addAttempt(session, grade: .blue, attempts: 3, result: .send)
        addAttempt(session, grade: .red, attempts: 5, result: .project)

        let summary = StatsAggregator.summary(of: [session])

        #expect(summary.problemCount == 3)
        #expect(summary.sendCount == 2)
        #expect(summary.flashCount == 1)
        #expect(summary.attemptCount == 9)
        #expect(abs(summary.completionRate - 2.0 / 3.0) < 0.001)
        #expect(abs(summary.flashRate - 1.0 / 3.0) < 0.001)
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

    @Test func sendCountPerGradeIgnoresProjects() {
        let session = makeSession(daysAgo: 0)
        addAttempt(session, grade: .blue, result: .flash)
        addAttempt(session, grade: .blue, result: .send)
        addAttempt(session, grade: .blue, result: .project)

        let counts = StatsAggregator.sendCountPerGrade(of: [session])

        #expect(counts[.blue] == 2)
        #expect(counts[.red] == nil)
    }

    @Test func hardestSendPicksHighestGrade() {
        let session = makeSession(daysAgo: 0)
        addAttempt(session, grade: .black, result: .send)
        addAttempt(session, grade: .white, result: .project)
        addAttempt(session, grade: .red, result: .flash)

        let hardest = StatsAggregator.hardestSend(of: [session])

        #expect(hardest?.colorGrade == .black)
    }

    @Test func proudestSendBreaksTiesByAttemptCount() {
        let session = makeSession(daysAgo: 0)
        addAttempt(session, grade: .black, attempts: 2, result: .send)
        addAttempt(session, grade: .black, attempts: 9, result: .send)

        let proudest = StatsAggregator.proudestSend(of: [session])

        #expect(proudest?.attemptCount == 9)
    }

    @Test func sendRatePerStyleComputesPerStyleRatio() {
        let session = makeSession(daysAgo: 0)
        addAttempt(session, grade: .red, styles: [.sloper], result: .send)
        addAttempt(session, grade: .red, styles: [.sloper], result: .project)
        addAttempt(session, grade: .red, styles: [.crimp], result: .flash)

        let rates = StatsAggregator.sendRatePerStyle(of: [session])

        #expect(abs((rates[.sloper] ?? 0) - 0.5) < 0.001)
        #expect(abs((rates[.crimp] ?? 0) - 1.0) < 0.001)
    }

    @Test func proudestSendBreaksFullTieByLatestSessionDate() {
        let referenceDate = Date.now
        let earlierSession = makeSession(daysAgo: 10, referenceDate: referenceDate)
        let laterSession = makeSession(daysAgo: 1, referenceDate: referenceDate)
        addAttempt(earlierSession, grade: .black, attempts: 3, result: .send)
        addAttempt(laterSession, grade: .black, attempts: 3, result: .send)

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
