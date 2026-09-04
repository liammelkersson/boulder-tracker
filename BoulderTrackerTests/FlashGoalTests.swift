import Testing
import Foundation
@testable import BoulderTracker

@MainActor
struct FlashGoalTests {
    private let calendar = Calendar(identifier: .iso8601)
    private let referenceDate = Date(timeIntervalSince1970: 1_750_000_000)

    private func makeSession(daysAgo: Int) -> Session {
        let start = calendar.date(byAdding: .day, value: -daysAgo, to: referenceDate)!
        let session = Session(startTime: start, gym: nil, partners: [])
        session.endTime = start.addingTimeInterval(3600)
        return session
    }

    @discardableResult
    private func addProblem(_ session: Session, grade: ColorGrade, flashes: Int = 0,
                            sends: Int = 0, falls: Int = 0) -> SessionProblem {
        let problem = SessionProblem(
            name: "Problem \(session.problems.count + 1)", colorGrade: grade, styles: [],
            flashCount: flashes, sendCount: sends, fallCount: falls
        )
        session.problems.append(problem)
        return problem
    }

    private func makeGoal(recent: [Session], live: Session) -> FlashGoal? {
        FlashGoal(recentSessions: recent, liveSession: live,
                  referenceDate: referenceDate, calendar: calendar)
    }

    @Test func targetBandSitsOneBandBelowTheHardestRecentSend() {
        let past = makeSession(daysAgo: 10)
        addProblem(past, grade: .red, sends: 1)

        let goal = makeGoal(recent: [past], live: makeSession(daysAgo: 0))

        #expect(goal?.band == .blue)
        #expect(FlashGoal.flashCount == 3)
    }

    @Test func aBottomBandClimberKeepsTheBottomBandAsTheTarget() {
        let past = makeSession(daysAgo: 10)
        addProblem(past, grade: .green, sends: 1)

        #expect(makeGoal(recent: [past], live: makeSession(daysAgo: 0))?.band == .green)
    }

    @Test func sendsOlderThanTheWindowDoNotSetTheBand() {
        let stale = makeSession(daysAgo: 200)
        addProblem(stale, grade: .black, sends: 1)
        let recent = makeSession(daysAgo: 5)
        addProblem(recent, grade: .blue, sends: 1)

        #expect(makeGoal(recent: [stale, recent], live: makeSession(daysAgo: 0))?.band == .green)
    }

    @Test func thereIsNoGoalWithoutARecentSend() {
        let stale = makeSession(daysAgo: 200)
        addProblem(stale, grade: .red, sends: 1)

        #expect(makeGoal(recent: [stale], live: makeSession(daysAgo: 0)) == nil)
    }

    @Test func thereIsNoGoalOnAFirstEverSession() {
        #expect(makeGoal(recent: [], live: makeSession(daysAgo: 0)) == nil)
    }

    @Test func fallsAndUnknownGradesNeverSetTheBand() {
        let past = makeSession(daysAgo: 10)
        addProblem(past, grade: .black, falls: 6)
        addProblem(past, grade: .unknown, sends: 2)

        #expect(makeGoal(recent: [past], live: makeSession(daysAgo: 0)) == nil)
    }

    @Test func progressCountsFlashesLoggedAtTheTargetBand() {
        let past = makeSession(daysAgo: 10)
        addProblem(past, grade: .red, sends: 1)
        let live = makeSession(daysAgo: 0)
        addProblem(live, grade: .blue, flashes: 2)

        let goal = makeGoal(recent: [past], live: live)

        #expect(goal?.flashesLogged == 2)
        #expect(goal?.isMet == false)
    }

    @Test func sendsAtTheTargetBandDoNotCountAsFlashes() {
        let past = makeSession(daysAgo: 10)
        addProblem(past, grade: .red, sends: 1)
        let live = makeSession(daysAgo: 0)
        addProblem(live, grade: .blue, sends: 3, falls: 2)

        #expect(makeGoal(recent: [past], live: live)?.flashesLogged == 0)
    }

    @Test func flashesAtOtherBandsDoNotCount() {
        let past = makeSession(daysAgo: 10)
        addProblem(past, grade: .red, sends: 1)
        let live = makeSession(daysAgo: 0)
        addProblem(live, grade: .green, flashes: 4)

        #expect(makeGoal(recent: [past], live: live)?.flashesLogged == 0)
    }

    @Test func threeFlashesAtTheTargetBandMeetTheGoal() {
        let past = makeSession(daysAgo: 10)
        addProblem(past, grade: .red, sends: 1)
        let live = makeSession(daysAgo: 0)
        addProblem(live, grade: .blue, flashes: 1)
        addProblem(live, grade: .blue, flashes: 2)

        let goal = makeGoal(recent: [past], live: live)

        #expect(goal?.flashesLogged == 3)
        #expect(goal?.isMet == true)
    }
}
