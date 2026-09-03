import Testing
import Foundation
import SwiftData
@testable import BoulderTracker

@MainActor
struct ProjectStatsTests {
    private func makeSession(daysAgo: Int, context: ModelContext) -> Session {
        let start = Date.now.addingTimeInterval(TimeInterval(-daysAgo) * 24 * 3600)
        let session = Session(startTime: start, gym: nil, partners: [])
        context.insert(session)
        return session
    }

    @Test func countsDistinctSessionsNotProblemRows() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let project = Project(name: "Elektra")
        context.insert(project)
        let firstSession = makeSession(daysAgo: 6, context: context)
        let secondSession = makeSession(daysAgo: 2, context: context)
        for session in [firstSession, firstSession, secondSession] {
            let problem = SessionProblem(name: "Elektra", colorGrade: .red, styles: [], fallCount: 2)
            session.problems.append(problem)
            problem.project = project
        }
        try context.save()

        let stats = ProjectStats(project: project)

        #expect(stats.sessionCount == 2)
        #expect(stats.attemptCount == 6)
        #expect(stats.lastAttemptDate == secondSession.startTime)
    }

    @Test func emptyProjectHasNoAttempts() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let project = Project(name: "Fresh")
        context.insert(project)
        try context.save()

        let stats = ProjectStats(project: project)

        #expect(stats.sessionCount == 0)
        #expect(stats.attemptCount == 0)
        #expect(stats.lastAttemptDate == nil)
    }
}
