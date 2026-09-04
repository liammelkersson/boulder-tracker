import Testing
import Foundation
@testable import BoulderTracker

@MainActor
struct StyleCoverageTests {
    private func makeSession() -> Session {
        Session(startTime: .now, gym: nil, partners: [])
    }

    private func addProblem(_ session: Session, styles: [RouteStyle]) {
        session.problems.append(SessionProblem(
            name: "Problem \(session.problems.count + 1)", colorGrade: .blue, styles: styles
        ))
    }

    private func group(_ groups: [StyleCoverageGroup],
                       _ wanted: RouteStyleGroup) -> StyleCoverageGroup? {
        groups.first { $0.group == wanted }
    }

    @Test func terrainAndHoldsAreTheOnlyGroups() {
        #expect(RouteStyleGroup.allCases == [.terrain, .holds])
    }

    @Test func movementStylesBelongToNoGroup() {
        let grouped = Set(RouteStyleGroup.allCases.flatMap(\.styles))

        #expect(!grouped.contains(.dyno))
        #expect(!grouped.contains(.compression))
        #expect(!grouped.contains(.coordination))
        #expect(!grouped.contains(.mantle))
    }

    @Test func nothingIsTriedWithoutAnyProblem() {
        let groups = StyleCoverage.groups(of: [makeSession()])

        #expect(group(groups, .terrain)?.triedStyles.isEmpty == true)
        #expect(group(groups, .terrain)?.untriedStyles == RouteStyleGroup.terrain.styles)
    }

    @Test func aTaggedStyleMovesFromUntriedToTried() {
        let session = makeSession()
        addProblem(session, styles: [.slab])

        let groups = StyleCoverage.groups(of: [session])

        #expect(group(groups, .terrain)?.triedStyles == [.slab])
        #expect(group(groups, .terrain)?.untriedStyles.contains(.slab) == false)
    }

    @Test func stylesAreSortedIntoTheirOwnGroup() {
        let session = makeSession()
        addProblem(session, styles: [.roof, .crimp])

        let groups = StyleCoverage.groups(of: [session])

        #expect(group(groups, .terrain)?.triedStyles == [.roof])
        #expect(group(groups, .holds)?.triedStyles == [.crimp])
    }

    @Test func ungroupedStylesAreIgnored() {
        let session = makeSession()
        addProblem(session, styles: [.dyno])

        let groups = StyleCoverage.groups(of: [session])

        #expect(groups.allSatisfy { $0.triedStyles.isEmpty })
    }

    @Test func aFallStillCountsAsTried() {
        let session = makeSession()
        session.problems.append(SessionProblem(
            name: "Bailed", colorGrade: .red, styles: [.overhang], fallCount: 3
        ))

        #expect(group(StyleCoverage.groups(of: [session]), .terrain)?.triedStyles == [.overhang])
    }

    @Test func triedStylesKeepDeclarationOrderAndDoNotRepeat() {
        let session = makeSession()
        addProblem(session, styles: [.vertical, .slab])
        addProblem(session, styles: [.slab])

        #expect(group(StyleCoverage.groups(of: [session]), .terrain)?.triedStyles
                == [.slab, .vertical])
    }

    @Test func aFullyCoveredGroupHasNothingUntried() {
        let session = makeSession()
        addProblem(session, styles: RouteStyleGroup.holds.styles)

        let holds = group(StyleCoverage.groups(of: [session]), .holds)

        #expect(holds?.untriedStyles.isEmpty == true)
        #expect(holds?.isFullyCovered == true)
    }
}
