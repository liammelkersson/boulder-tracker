import Testing
import Foundation
@testable import BoulderTracker

@MainActor
struct GradePyramidTests {
    private func makeSession() -> Session {
        Session(startTime: .now, gym: nil, partners: [])
    }

    private func addSends(_ session: Session, grade: ColorGrade, problems: Int,
                          sendsEach: Int = 1) {
        for index in 0..<problems {
            session.problems.append(SessionProblem(
                name: "\(grade.displayName) \(index)", colorGrade: grade, styles: [],
                sendCount: sendsEach
            ))
        }
    }

    @Test func pyramidIsEmptyWithoutAnySend() {
        let session = makeSession()
        session.problems.append(SessionProblem(
            name: "Fell off", colorGrade: .red, styles: [], fallCount: 4
        ))

        let pyramid = GradePyramid(sessions: [session])

        #expect(pyramid.tiers.isEmpty)
        #expect(!pyramid.isTotemPole)
    }

    @Test func topTierIsTheHardestBandSentAndTargetsDoubleDownward() {
        let session = makeSession()
        addSends(session, grade: .black, problems: 1)

        let pyramid = GradePyramid(sessions: [session])

        #expect(pyramid.tiers.map(\.grade) == [.black, .red, .blue, .green])
        #expect(pyramid.tiers.map(\.target) == [1, 2, 4, 8])
    }

    @Test func tiersStopAtTheBottomOfTheLadder() {
        let session = makeSession()
        addSends(session, grade: .red, problems: 1)

        let pyramid = GradePyramid(sessions: [session])

        #expect(pyramid.tiers.map(\.grade) == [.red, .blue, .green])
        #expect(pyramid.tiers.map(\.target) == [1, 2, 4])
    }

    @Test func aTopBandAtTheBottomOfTheLadderLeavesASingleTier() {
        let session = makeSession()
        addSends(session, grade: .green, problems: 3)

        let pyramid = GradePyramid(sessions: [session])

        #expect(pyramid.tiers.map(\.grade) == [.green])
        #expect(pyramid.tiers.first?.sentCount == 3)
    }

    @Test func warmupAndUnknownBandsNeverFormATier() {
        let session = makeSession()
        addSends(session, grade: .yellow, problems: 5)
        addSends(session, grade: .unknown, problems: 5)

        let pyramid = GradePyramid(sessions: [session])

        #expect(pyramid.tiers.isEmpty)
    }

    @Test func repeatAscentsOfOneProblemCountOnce() {
        let session = makeSession()
        addSends(session, grade: .blue, problems: 1, sendsEach: 5)

        let pyramid = GradePyramid(sessions: [session])

        #expect(pyramid.tiers.first?.sentCount == 1)
    }

    @Test func aFlashCountsTowardsTheTier() {
        let session = makeSession()
        session.problems.append(SessionProblem(
            name: "Flashed", colorGrade: .blue, styles: [], flashCount: 1
        ))

        let pyramid = GradePyramid(sessions: [session])

        #expect(pyramid.tiers.first?.grade == .blue)
        #expect(pyramid.tiers.first?.sentCount == 1)
    }

    @Test func aThinBaseUnderAMetTopTierIsATotemPole() {
        let session = makeSession()
        addSends(session, grade: .red, problems: 1)
        addSends(session, grade: .blue, problems: 1)
        addSends(session, grade: .green, problems: 1)

        let pyramid = GradePyramid(sessions: [session])

        #expect(pyramid.isTotemPole)
        #expect(!pyramid.isBalanced)
        #expect(pyramid.unmetTiers.map(\.grade) == [.blue, .green])
        #expect(pyramid.unmetTiers.map(\.shortfall) == [1, 3])
    }

    @Test func everyTierMetIsBalancedAndNotATotemPole() {
        let session = makeSession()
        addSends(session, grade: .red, problems: 1)
        addSends(session, grade: .blue, problems: 2)
        addSends(session, grade: .green, problems: 4)

        let pyramid = GradePyramid(sessions: [session])

        #expect(pyramid.isBalanced)
        #expect(!pyramid.isTotemPole)
        #expect(pyramid.unmetTiers.isEmpty)
    }

    @Test func aSingleTierPyramidIsNotATotemPole() {
        let session = makeSession()
        addSends(session, grade: .green, problems: 1)

        let pyramid = GradePyramid(sessions: [session])

        #expect(!pyramid.isTotemPole)
        #expect(pyramid.isBalanced)
    }

    @Test func nextBandIsTheOneAboveTheTopTier() {
        let session = makeSession()
        addSends(session, grade: .blue, problems: 1)

        #expect(GradePyramid(sessions: [session]).nextBand == .red)
    }

    @Test func theTopOfTheLadderHasNoNextBand() {
        let session = makeSession()
        addSends(session, grade: .white, problems: 1)

        #expect(GradePyramid(sessions: [session]).nextBand == nil)
    }

    @Test func sendsAcrossSessionsAccumulateIntoOnePyramid() {
        let first = makeSession()
        let second = makeSession()
        addSends(first, grade: .blue, problems: 1)
        addSends(second, grade: .green, problems: 2)

        let pyramid = GradePyramid(sessions: [first, second])

        #expect(pyramid.tiers.map(\.sentCount) == [1, 2])
    }
}
