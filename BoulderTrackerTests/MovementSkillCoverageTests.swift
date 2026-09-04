import Testing
import Foundation
@testable import BoulderTracker

@MainActor
struct MovementSkillCoverageTests {
    private func makeSession() -> Session {
        Session(startTime: .now, gym: nil, partners: [])
    }

    private func addProblem(_ session: Session, skills: [MovementSkill]) {
        let problem = SessionProblem(
            name: "Problem \(session.problems.count + 1)", colorGrade: .blue, styles: []
        )
        problem.skills = skills
        session.problems.append(problem)
    }

    @Test func everySkillGetsATallyEvenWhenNeverTagged() {
        let tallies = MovementSkillCoverage.tallies(of: [makeSession()])

        #expect(tallies.map(\.skill) == MovementSkill.allCases)
        #expect(tallies.allSatisfy { $0.taggedCount == 0 })
    }

    @Test func talliesCountTheProblemsCarryingEachSkill() {
        let session = makeSession()
        addProblem(session, skills: [.cross, .flagging])
        addProblem(session, skills: [.flagging])

        let tallies = MovementSkillCoverage.tallies(of: [session])
        let counts = Dictionary(
            uniqueKeysWithValues: tallies.map { ($0.skill, $0.taggedCount) }
        )

        #expect(counts[.flagging] == 2)
        #expect(counts[.cross] == 1)
        #expect(counts[.smear] == 0)
    }

    @Test func talliesAccumulateAcrossSessions() {
        let first = makeSession()
        let second = makeSession()
        addProblem(first, skills: [.deadpoint])
        addProblem(second, skills: [.deadpoint])

        let tallies = MovementSkillCoverage.tallies(of: [first, second])

        #expect(tallies.first { $0.skill == .deadpoint }?.taggedCount == 2)
    }

    @Test func theWeakestSkillIsTheLeastTaggedOne() {
        let session = makeSession()
        for skill in MovementSkill.allCases where skill != .cross {
            addProblem(session, skills: [skill])
        }

        #expect(MovementSkillCoverage.weakestSkill(of: [session]) == .cross)
    }

    @Test func tiesOnTheWeakestSkillResolveByLadderOrder() {
        let session = makeSession()
        addProblem(session, skills: [.footSwap, .flagging, .deadpoint, .smear])

        #expect(MovementSkillCoverage.weakestSkill(of: [session]) == .hipRotation)
    }

    @Test func thereIsNoWeakestSkillBeforeAnythingIsTagged() {
        let session = makeSession()
        addProblem(session, skills: [])

        #expect(MovementSkillCoverage.weakestSkill(of: [session]) == nil)
    }

    @Test func untaggedProblemsAreCounted() {
        let session = makeSession()
        addProblem(session, skills: [.cross])
        addProblem(session, skills: [])
        addProblem(session, skills: [])

        #expect(MovementSkillCoverage.untaggedProblemCount(of: [session]) == 2)
    }

    @Test func nothingIsUntaggedWhenEveryProblemCarriesASkill() {
        let session = makeSession()
        addProblem(session, skills: [.smear])

        #expect(MovementSkillCoverage.untaggedProblemCount(of: [session]) == 0)
    }

    @Test func untaggedProblemsAccumulateAcrossSessions() {
        let first = makeSession()
        let second = makeSession()
        addProblem(first, skills: [])
        addProblem(second, skills: [])

        #expect(MovementSkillCoverage.untaggedProblemCount(of: [first, second]) == 2)
    }
}
