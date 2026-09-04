import Testing
import Foundation
import SwiftData
@testable import BoulderTracker

@MainActor
struct QuickLogEntryTests {
    private func makeSession(in context: ModelContext) -> Session {
        let session = Session(startTime: .now, gym: nil, partners: [])
        context.insert(session)
        return session
    }

    @Test func reusesTheUnnamedProblemLoggedForThatGrade() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let session = makeSession(in: context)
        let existing = SessionProblem(name: "", colorGrade: .red, styles: [])
        session.problems.append(existing)
        try context.save()

        let problem = QuickLogEntry.problem(for: .red, in: session)

        #expect(problem === existing)
        #expect(session.problems.count == 1)
    }

    @Test func createsAnUnnamedProblemWhenTheGradeIsNew() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let session = makeSession(in: context)
        session.problems.append(SessionProblem(name: "", colorGrade: .blue, styles: []))
        try context.save()

        let problem = QuickLogEntry.problem(for: .black, in: session)

        #expect(problem.colorGrade == .black)
        #expect(problem.name.isEmpty)
        #expect(session.problems.count == 2)
    }

    @Test func neverHijacksANamedProblemOfTheSameGrade() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let session = makeSession(in: context)
        let named = SessionProblem(name: "Elektra", colorGrade: .red, styles: [])
        session.problems.append(named)
        try context.save()

        let problem = QuickLogEntry.problem(for: .red, in: session)

        #expect(problem !== named)
        #expect(session.problems.count == 2)
    }
}
