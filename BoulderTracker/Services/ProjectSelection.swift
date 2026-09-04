import Foundation
import SwiftData

/// Single writer for `Project.isCurrent`, so the "one pinned project"
/// invariant lives in one place instead of at every call site.
enum ProjectSelection {
    /// Pins an active project to the Home card and unpins the rest. Sent and
    /// archived projects are not pinnable, so the card never shows finished
    /// work. Does not save; the caller does.
    static func makeCurrent(_ project: Project, in context: ModelContext) {
        guard project.status == .active else { return }
        let stored = (try? context.fetch(FetchDescriptor<Project>()))?.persisted ?? []
        for other in stored where other.persistentModelID != project.persistentModelID {
            other.isCurrent = false
        }
        project.isCurrent = true
    }

    /// The project the Home card shows: the user's pin when set, otherwise the
    /// active project worked in the most sessions, most recent breaking ties.
    static func current(from projects: [Project]) -> Project? {
        let active = projects.persisted.filter { $0.status == .active }
        if let pinned = active.first(where: \.isCurrent) { return pinned }
        return active.max { lhs, rhs in
            let lhsStats = ProjectStats(project: lhs)
            let rhsStats = ProjectStats(project: rhs)
            if lhsStats.sessionCount != rhsStats.sessionCount {
                return lhsStats.sessionCount < rhsStats.sessionCount
            }
            return (lhsStats.lastAttemptDate ?? .distantPast)
                < (rhsStats.lastAttemptDate ?? .distantPast)
        }
    }
}
