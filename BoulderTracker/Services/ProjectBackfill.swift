import Foundation
import OSLog
import SwiftData

/// One-time migration: projects used to be derived on the fly from session
/// problems. This turns every group that rule produced into a stored `Project`
/// row so the user can edit, complete, archive, and delete them.
enum ProjectBackfill {
    static let completedFlagKey = "pref.projectBackfillDone"

    /// Read once here rather than from `AppPreferences`, which drops the key
    /// as part of this migration.
    private static let legacyCurrentProjectNameKey = "pref.currentProjectName"

    static func runIfNeeded(context: ModelContext, defaults: UserDefaults) {
        guard !defaults.bool(forKey: completedFlagKey) else { return }
        do {
            try backfillProjects(in: context)
            adoptLegacyCurrentProject(in: context, defaults: defaults)
            defaults.set(true, forKey: completedFlagKey)
        } catch {
            // Retried on next launch because the flag stays unset.
            Logger.persistence.error("Project backfill failed: \(error)")
        }
    }

    static func backfillProjects(in context: ModelContext) throws {
        let sessions = try context.fetch(FetchDescriptor<Session>()).persisted
        let existingKeys = Set(
            try context.fetch(FetchDescriptor<Project>()).map {
                GroupKey(name: $0.name, gymName: $0.gym?.name)
            }
        )
        for (key, occurrences) in legacyGroups(in: sessions) where !existingKeys.contains(key) {
            context.insert(makeProject(named: key.name, from: occurrences))
        }
        for problem in sessions.flatMap(\.problems) {
            problem.isProject = false
        }
        try context.save()
    }

    private static func makeProject(named name: String,
                                    from occurrences: [SessionProblem]) -> Project {
        let latest = occurrences.max { attemptDate(of: $0) < attemptDate(of: $1) }
        let project = Project(
            name: name,
            colorGrade: latest?.colorGrade ?? .unknown,
            gym: latest?.session?.gym,
            status: occurrences.contains(where: \.wasSent) ? .sent : .active,
            createdDate: occurrences.map(attemptDate(of:)).min() ?? .now
        )
        project.isSampleData = occurrences.allSatisfy { $0.session?.isSampleData == true }
        project.problems = occurrences
        return project
    }

    /// The rule `ProjectAggregator` used before projects were stored: a named
    /// problem is a project when it was explicitly marked, or when it is
    /// unsent and has logged falls.
    private static func legacyGroups(in sessions: [Session]) -> [GroupKey: [SessionProblem]] {
        let named = sessions.flatMap(\.problems).filter { !$0.name.isEmpty }
        let byKey = Dictionary(grouping: named) {
            GroupKey(name: $0.name, gymName: $0.session?.gym?.name)
        }
        return byKey.filter { _, occurrences in
            let marked = occurrences.contains(where: \.isProject)
            let sent = occurrences.contains(where: \.wasSent)
            let hasFalls = occurrences.contains { $0.fallCount > 0 }
            return marked || (!sent && hasFalls)
        }
    }

    private static func adoptLegacyCurrentProject(in context: ModelContext,
                                                  defaults: UserDefaults) {
        guard let storedName = defaults.string(forKey: legacyCurrentProjectNameKey),
              !storedName.isEmpty,
              let match = try? context.fetch(FetchDescriptor<Project>())
                  .first(where: { $0.name == storedName && $0.status == .active })
        else { return }
        ProjectSelection.makeCurrent(match, in: context)
        context.saveReportingFailure(operation: "current project migration")
        defaults.removeObject(forKey: legacyCurrentProjectNameKey)
    }

    private static func attemptDate(of problem: SessionProblem) -> Date {
        problem.session?.startTime ?? .distantPast
    }

    private struct GroupKey: Hashable {
        let name: String
        let gymName: String?
    }
}
