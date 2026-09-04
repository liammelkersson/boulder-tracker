import Testing
import Foundation
import SwiftData
@testable import BoulderTracker

@MainActor
struct ProjectLinkingTests {
    private func makeProblem(named name: String, gym: Gym?,
                             styles: [RouteStyle] = [],
                             context: ModelContext) -> SessionProblem {
        let session = Session(startTime: .now, gym: gym, partners: [])
        context.insert(session)
        let problem = SessionProblem(name: name, colorGrade: .red, styles: styles)
        session.problems.append(problem)
        return problem
    }

    @Test func createsAProjectForANamedProblem() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let gym = Gym(name: "Klätterverket")
        context.insert(gym)
        let problem = makeProblem(named: "Elektra", gym: gym, context: context)

        let project = ProjectLinking.linkProject(to: problem, in: context)

        #expect(project?.name == "Elektra")
        #expect(project?.gym?.name == "Klätterverket")
        #expect(project?.colorGrade == .red)
        #expect(problem.project === project)
    }

    @Test func reusesAnOpenProjectWithTheSameNameAndGym() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let gym = Gym(name: "Klätterverket")
        context.insert(gym)
        let first = makeProblem(named: "Elektra", gym: gym, context: context)
        let second = makeProblem(named: "Elektra", gym: gym, context: context)

        let firstProject = ProjectLinking.linkProject(to: first, in: context)
        let secondProject = ProjectLinking.linkProject(to: second, in: context)
        try context.save()

        #expect(firstProject === secondProject)
        #expect(try context.fetchCount(FetchDescriptor<Project>()) == 1)
    }

    @Test func doesNotReuseAnArchivedProject() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let archived = Project(name: "Elektra", status: .archived)
        context.insert(archived)
        let problem = makeProblem(named: "Elektra", gym: nil, context: context)

        let project = ProjectLinking.linkProject(to: problem, in: context)

        #expect(project !== archived)
    }

    @Test func refusesAnUnnamedProblem() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let problem = makeProblem(named: "", gym: nil, context: context)

        #expect(ProjectLinking.linkProject(to: problem, in: context) == nil)
        #expect(problem.project == nil)
    }

    @Test func createdProjectInheritsTheProblemStyles() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let problem = makeProblem(
            named: "Elektra", gym: nil, styles: [.crimp, .overhang], context: context
        )

        let project = ProjectLinking.linkProject(to: problem, in: context)

        #expect(project?.styles == [.crimp, .overhang])
    }

    @Test func reusedProjectKeepsItsOwnStyles() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let existing = Project(name: "Elektra", colorGrade: .red, styles: [.slab])
        context.insert(existing)
        let problem = makeProblem(named: "Elektra", gym: nil, styles: [.dyno], context: context)

        ProjectLinking.linkProject(to: problem, in: context)

        #expect(existing.styles == [.slab])
    }

    @Test func unlinkClearsTheProject() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let problem = makeProblem(named: "Elektra", gym: nil, context: context)
        ProjectLinking.linkProject(to: problem, in: context)

        ProjectLinking.unlinkProject(from: problem)

        #expect(problem.project == nil)
    }
}
