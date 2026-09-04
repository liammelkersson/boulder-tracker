import Testing
import Foundation
import SwiftData
@testable import BoulderTracker

@MainActor
struct SessionLogWriterTests {
    private final class RecordedCalls {
        var announced: [(grade: ColorGrade, result: AttemptResult)] = []
        var refreshCount = 0
    }

    private func makeWriter(
        context: ModelContext, calls: RecordedCalls
    ) -> SessionLogWriter {
        SessionLogWriter(
            context: context,
            announceAttempt: { problem, _, result in
                calls.announced.append((problem.colorGrade, result))
            },
            refreshActivity: { _ in calls.refreshCount += 1 }
        )
    }

    private func makeLiveSession(in context: ModelContext) -> Session {
        let session = Session(startTime: .now, gym: nil, partners: [])
        context.insert(session)
        return session
    }

    @Test func logsASendOnTheLiveSession() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let session = makeLiveSession(in: context)
        try context.save()
        let calls = RecordedCalls()

        makeWriter(context: context, calls: calls).logSend(grade: .red)

        #expect(session.problems.count == 1)
        #expect(session.problems.first?.colorGrade == .red)
        #expect(session.problems.first?.sendCount == 1)
        #expect(calls.announced.map(\.result) == [.send])
        #expect(calls.refreshCount == 1)
    }

    @Test func reusesTheQuickLogProblemForThatGrade() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let session = makeLiveSession(in: context)
        let existing = SessionProblem(name: "", colorGrade: .red, styles: [])
        session.problems.append(existing)
        try context.save()
        let calls = RecordedCalls()
        let writer = makeWriter(context: context, calls: calls)

        writer.logSend(grade: .red)
        writer.logSend(grade: .red)

        #expect(session.problems.count == 1)
        #expect(existing.sendCount == 2)
    }

    @Test func doesNothingWithoutALiveSession() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let ended = makeLiveSession(in: context)
        ended.endTime = .now
        try context.save()
        let calls = RecordedCalls()

        makeWriter(context: context, calls: calls).logSend(grade: .red)

        #expect(ended.problems.isEmpty)
        #expect(calls.announced.isEmpty)
        #expect(calls.refreshCount == 0)
    }

    @Test func completesALinkedProjectLikeAnyOtherSend() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let session = makeLiveSession(in: context)
        let problem = SessionProblem(name: "", colorGrade: .red, styles: [])
        session.problems.append(problem)
        let project = Project(name: "Elektra")
        context.insert(project)
        problem.project = project
        try context.save()

        makeWriter(context: context, calls: RecordedCalls()).logSend(grade: .red)

        #expect(project.status == .sent)
    }
}
