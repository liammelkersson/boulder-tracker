import Foundation
import SwiftData

/// Turns "mark this problem as a project" into a stored `Project`, reusing an
/// open one with the same name and gym so the same problem flagged in two
/// sessions stays a single project.
enum ProjectLinking {
    @discardableResult
    static func linkProject(to problem: SessionProblem, in context: ModelContext) -> Project? {
        guard !problem.name.isEmpty else { return nil }
        let project = openProject(named: problem.name, gym: problem.session?.gym, in: context)
            ?? insertProject(for: problem, in: context)
        problem.project = project
        return project
    }

    static func unlinkProject(from problem: SessionProblem) {
        problem.project = nil
    }

    private static func openProject(named name: String, gym: Gym?,
                                    in context: ModelContext) -> Project? {
        let stored = (try? context.fetch(FetchDescriptor<Project>()))?.persisted ?? []
        return stored.first {
            $0.status != .archived && $0.name == name && $0.gym?.name == gym?.name
        }
    }

    private static func insertProject(for problem: SessionProblem,
                                      in context: ModelContext) -> Project {
        let project = Project(
            name: problem.name,
            colorGrade: problem.colorGrade,
            gym: problem.session?.gym,
            status: problem.wasSent ? .sent : .active
        )
        project.isSampleData = problem.session?.isSampleData ?? false
        context.insert(project)
        return project
    }
}
