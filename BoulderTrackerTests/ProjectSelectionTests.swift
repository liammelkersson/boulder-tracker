import Testing
import Foundation
import SwiftData
@testable import BoulderTracker

@MainActor
struct ProjectSelectionTests {
    @Test func makeCurrentLeavesExactlyOneCurrentProject() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let first = Project(name: "Elektra")
        first.isCurrent = true
        let second = Project(name: "Moonwalk")
        context.insert(first)
        context.insert(second)
        try context.save()

        ProjectSelection.makeCurrent(second, in: context)
        try context.save()

        #expect(second.isCurrent)
        #expect(first.isCurrent == false)
    }

    @Test func makeCurrentIgnoresSentAndArchivedProjects() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let sent = Project(name: "Done", status: .sent)
        context.insert(sent)
        try context.save()

        ProjectSelection.makeCurrent(sent, in: context)

        #expect(sent.isCurrent == false)
    }

    @Test func currentPrefersThePinnedActiveProject() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let pinned = Project(name: "Pinned")
        pinned.isCurrent = true
        let other = Project(name: "Other")
        context.insert(pinned)
        context.insert(other)
        try context.save()

        #expect(ProjectSelection.current(from: [other, pinned])?.name == "Pinned")
    }

    @Test func currentFallsBackToMostWorkedActiveProject() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let quiet = Project(name: "Quiet")
        let worked = Project(name: "Worked")
        context.insert(quiet)
        context.insert(worked)
        for daysAgo in [5, 3] {
            let start = Date.now.addingTimeInterval(TimeInterval(-daysAgo) * 24 * 3600)
            let session = Session(startTime: start, gym: nil, partners: [])
            context.insert(session)
            let problem = SessionProblem(name: "Worked", colorGrade: .red, styles: [], fallCount: 1)
            session.problems.append(problem)
            problem.project = worked
        }
        try context.save()

        #expect(ProjectSelection.current(from: [quiet, worked])?.name == "Worked")
    }

    @Test func currentIgnoresArchivedAndSentProjects() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let archived = Project(name: "Archived", status: .archived)
        let sent = Project(name: "Sent", status: .sent)
        context.insert(archived)
        context.insert(sent)
        try context.save()

        #expect(ProjectSelection.current(from: [archived, sent]) == nil)
    }
}
