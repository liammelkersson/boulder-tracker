import Testing
@testable import BoulderTracker

struct AttemptResultTests {
    @Test func flashAndSendCountAsSends() {
        #expect(AttemptResult.flash.countsAsSend)
        #expect(AttemptResult.send.countsAsSend)
        #expect(!AttemptResult.fall.countsAsSend)
    }

    @Test func recordResultIncrementsMatchingTally() {
        let problem = SessionProblem(name: "Elektra", colorGrade: .blue, styles: [])
        problem.recordResult(.flash)
        problem.recordResult(.fall)
        problem.recordResult(.fall)
        problem.recordResult(.send)

        #expect(problem.flashCount == 1)
        #expect(problem.sendCount == 1)
        #expect(problem.fallCount == 2)
        #expect(problem.totalLogs == 4)
        #expect(problem.wasSent)
        #expect(problem.wasFlashed)
    }

    @Test func fallsAloneDoNotCountAsSent() {
        let problem = SessionProblem(name: "The Roof", colorGrade: .red, styles: [])
        problem.recordResult(.fall)
        #expect(!problem.wasSent)
        #expect(!problem.wasFlashed)
    }

    @Test func loggingASendCompletesTheLinkedProject() {
        let project = Project(name: "Elektra")
        let problem = SessionProblem(name: "Elektra", colorGrade: .red, styles: [])
        problem.project = project

        problem.recordResult(.send)

        #expect(project.status == .sent)
    }

    @Test func loggingAFallLeavesTheProjectActive() {
        let project = Project(name: "Elektra")
        let problem = SessionProblem(name: "Elektra", colorGrade: .red, styles: [])
        problem.project = project

        problem.recordResult(.fall)

        #expect(project.status == .active)
    }

    @Test func loggingASendLeavesAnArchivedProjectArchived() {
        let project = Project(name: "Elektra", status: .archived)
        let problem = SessionProblem(name: "Elektra", colorGrade: .red, styles: [])
        problem.project = project

        problem.recordResult(.flash)

        #expect(project.status == .archived)
    }
}
