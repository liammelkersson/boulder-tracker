import Foundation

/// A named problem worked across one or more sessions.
struct ProjectGroup: Identifiable {
    let name: String
    let gymName: String?
    let grade: ColorGrade
    let sessionCount: Int
    let wasSent: Bool
    let lastAttemptDate: Date

    var id: String { name + "|" + (gymName ?? "") }
}

enum ProjectAggregator {
    /// All projects: problems explicitly marked as project, plus recurring
    /// unsent named problems with logged falls. Open projects sort first.
    static func groups(in sessions: [Session]) -> [ProjectGroup] {
        let named = sessions.flatMap(\.problems).filter { !$0.name.isEmpty }
        let byKey = Dictionary(grouping: named) {
            GroupKey(name: $0.name, gymName: $0.session?.gym?.name)
        }
        return byKey.compactMap { key, occurrences -> ProjectGroup? in
            let marked = occurrences.contains(where: \.isProject)
            let sent = occurrences.contains(where: \.wasSent)
            let hasFalls = occurrences.contains { $0.fallCount > 0 }
            guard marked || (!sent && hasFalls) else { return nil }
            let latest = occurrences.max { attemptDate(of: $0) < attemptDate(of: $1) }
            return ProjectGroup(
                name: key.name,
                gymName: key.gymName,
                grade: latest?.colorGrade ?? .unknown,
                sessionCount: Set(occurrences.compactMap { $0.session?.persistentModelID }).count,
                wasSent: sent,
                lastAttemptDate: latest.map(attemptDate(of:)) ?? .distantPast
            )
        }
        .sorted { lhs, rhs in
            if lhs.wasSent != rhs.wasSent { return !lhs.wasSent }
            return lhs.lastAttemptDate > rhs.lastAttemptDate
        }
    }

    /// The project shown on Home: the user's pick when set and still open,
    /// otherwise the open project worked in the most sessions.
    static func currentProject(in sessions: [Session],
                               preferredName: String?) -> ProjectGroup? {
        let open = groups(in: sessions).filter { !$0.wasSent }
        if let preferredName,
           let preferred = open.first(where: { $0.name == preferredName }) {
            return preferred
        }
        return open.max { lhs, rhs in
            if lhs.sessionCount != rhs.sessionCount { return lhs.sessionCount < rhs.sessionCount }
            return lhs.lastAttemptDate < rhs.lastAttemptDate
        }
    }

    private struct GroupKey: Hashable {
        let name: String
        let gymName: String?
    }

    private static func attemptDate(of problem: SessionProblem) -> Date {
        problem.session?.startTime ?? .distantPast
    }
}
