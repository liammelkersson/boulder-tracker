import Testing
import Foundation
import SwiftData
@testable import BoulderTracker

@MainActor
struct ClimbingSessionStateTests {
    private func makeSession(in context: ModelContext) -> Session {
        let gym = Gym(name: "Klätterverket")
        context.insert(gym)
        let session = Session(startTime: .now, gym: gym, partners: [])
        context.insert(session)
        return session
    }

    @Test func countsFlashesAndSendsButNotFalls() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let session = makeSession(in: context)
        session.problems.append(
            SessionProblem(name: "", colorGrade: .red, styles: [],
                           flashCount: 1, sendCount: 2, fallCount: 4)
        )
        try context.save()

        let state = ClimbingSessionState.contentState(for: session, gradeSystem: .french)

        #expect(state.sendCount == 3)
    }

    @Test func talliesEveryLogPerGradeInDisplayOrder() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let session = makeSession(in: context)
        session.problems.append(
            SessionProblem(name: "", colorGrade: .red, styles: [], sendCount: 2)
        )
        session.problems.append(
            SessionProblem(name: "", colorGrade: .green, styles: [], fallCount: 1)
        )
        try context.save()

        let state = ClimbingSessionState.contentState(for: session, gradeSystem: .french)

        #expect(state.tally == [GradeTally(grade: .green, count: 1),
                                GradeTally(grade: .red, count: 2)])
    }

    @Test func omitsGradesWithNoLogsFromTheTally() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let session = makeSession(in: context)
        session.problems.append(SessionProblem(name: "", colorGrade: .blue, styles: []))
        try context.save()

        let state = ClimbingSessionState.contentState(for: session, gradeSystem: .french)

        #expect(state.tally.isEmpty)
    }

    @Test func carriesTheGradeSystemAndQuickGrades() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let session = makeSession(in: context)
        try context.save()

        let state = ClimbingSessionState.contentState(for: session, gradeSystem: .vScale)

        #expect(state.gradeSystem == .vScale)
        #expect(state.quickGrades == QuickLogGradeSelection.fallbackGrades)
        #expect(state.startTime == session.startTime)
    }

    @Test func attributesCarryTheSyncIDAndGymName() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let session = makeSession(in: context)
        try context.save()

        let attributes = ClimbingSessionState.attributes(for: session)

        #expect(attributes.sessionSyncID == session.syncID)
        #expect(attributes.gymName == "Klätterverket")
    }
}
