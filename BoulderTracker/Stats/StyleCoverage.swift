import Foundation

/// Which styles in one group a period touched, and which it skipped.
struct StyleCoverageGroup: Equatable, Identifiable {
    let group: RouteStyleGroup
    let triedStyles: [RouteStyle]
    let untriedStyles: [RouteStyle]

    var id: String { group.id }

    var isFullyCovered: Bool { untriedStyles.isEmpty }

    /// Names the gap, since "3/6" alone does not say which angle to go find.
    var coverageSummary: String {
        guard !isFullyCovered else { return "Every one covered" }
        guard !triedStyles.isEmpty else { return "Nothing logged yet" }
        let untried = untriedStyles.map(\.displayName).formatted(.list(type: .and))
        return "Still untried: \(untried)"
    }
}

/// Terrain and hold-type variety over a period. An attempt counts, sent or not:
/// the guide asks you to *try* a new angle, and falling off a roof still
/// teaches the roof.
enum StyleCoverage {
    static func groups(of sessions: [Session]) -> [StyleCoverageGroup] {
        let tagged = Set(sessions.flatMap(\.problems).flatMap(\.styles))
        return RouteStyleGroup.allCases.map { group in
            StyleCoverageGroup(
                group: group,
                triedStyles: group.styles.filter(tagged.contains),
                untriedStyles: group.styles.filter { !tagged.contains($0) }
            )
        }
    }
}
