import Testing
import Foundation
@testable import BoulderTracker

@MainActor
struct AchievementEngineTests {
    private func makeFinishedSession(hoursLong: Double = 1.5,
                                     endHour: Int = 18) -> Session {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        components.hour = endHour
        let end = Calendar.current.date(from: components)!
        let session = Session(
            startTime: end.addingTimeInterval(-hoursLong * 3600),
            gym: nil, partners: []
        )
        session.endTime = end
        return session
    }

    private func addProblem(_ session: Session, grade: ColorGrade,
                            styles: [RouteStyle] = [], flashes: Int = 0,
                            sends: Int = 0, falls: Int = 0) {
        session.problems.append(SessionProblem(
            name: "Problem", colorGrade: grade, styles: styles,
            flashCount: flashes, sendCount: sends, fallCount: falls
        ))
    }

    @Test func firstSessionUnlocksAfterOneSession() {
        let unlocked = AchievementEngine.newlyUnlocked(
            sessions: [makeFinishedSession()], alreadyUnlocked: []
        )
        #expect(unlocked.contains { $0.id == "first-session" })
    }

    @Test func alreadyUnlockedAreNotReturnedAgain() {
        let unlocked = AchievementEngine.newlyUnlocked(
            sessions: [makeFinishedSession()], alreadyUnlocked: ["first-session"]
        )
        #expect(!unlocked.contains { $0.id == "first-session" })
    }

    @Test func firstSendPerColorUnlocks() {
        let session = makeFinishedSession()
        addProblem(session, grade: .black, sends: 1, falls: 3)
        let unlocked = AchievementEngine.newlyUnlocked(sessions: [session], alreadyUnlocked: [])
        #expect(unlocked.contains { $0.id == "first-send-black" })
        #expect(!unlocked.contains { $0.id == "first-send-white" })
    }

    @Test func marathonRequiresThreeHours() {
        let short = makeFinishedSession(hoursLong: 2.9)
        let long = makeFinishedSession(hoursLong: 3.1)
        #expect(!AchievementEngine.newlyUnlocked(sessions: [short], alreadyUnlocked: [])
            .contains { $0.id == "marathon" })
        #expect(AchievementEngine.newlyUnlocked(sessions: [long], alreadyUnlocked: [])
            .contains { $0.id == "marathon" })
    }

    @Test func nightOwlRequiresFiveEveningSessions() {
        let fourEvenings = (0..<4).map { _ in makeFinishedSession(endHour: 22) }
        #expect(!AchievementEngine.newlyUnlocked(sessions: fourEvenings, alreadyUnlocked: [])
            .contains { $0.id == "night-owl" })
        let fiveEvenings = fourEvenings + [makeFinishedSession(endHour: 22)]
        #expect(AchievementEngine.newlyUnlocked(sessions: fiveEvenings, alreadyUnlocked: [])
            .contains { $0.id == "night-owl" })
    }

    @Test func flashTenBluesUnlocks() {
        let session = makeFinishedSession()
        for _ in 0..<10 {
            addProblem(session, grade: .blue, flashes: 1)
        }
        let unlocked = AchievementEngine.newlyUnlocked(sessions: [session], alreadyUnlocked: [])
        #expect(unlocked.contains { $0.id == "flash-10-blues" })
    }

    @Test func fiveStylesRequiresSendsInFiveDistinctStyles() {
        let session = makeFinishedSession()
        let styles: [RouteStyle] = [.dyno, .sloper, .crimp, .overhang, .slab]
        for style in styles {
            addProblem(session, grade: .green, styles: [style], sends: 1)
        }
        let unlocked = AchievementEngine.newlyUnlocked(sessions: [session], alreadyUnlocked: [])
        #expect(unlocked.contains { $0.id == "five-styles" })
    }

    @Test func globetrotterRequiresThreeGyms() {
        let sessions = ["A", "B", "C"].map { name in
            let session = makeFinishedSession()
            session.gym = Gym(name: name)
            return session
        }
        let unlocked = AchievementEngine.newlyUnlocked(sessions: sessions, alreadyUnlocked: [])
        #expect(unlocked.contains { $0.id == "globetrotter" })
    }

    @Test func allDefinitionIDsAreUnique() {
        let ids = AchievementEngine.definitions.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func progressFractionIsClampedToOne() {
        let sessions = [makeFinishedSession(), makeFinishedSession()]
        let firstSession = AchievementEngine.definitions.first { $0.id == "first-session" }!
        #expect(firstSession.progressFraction(in: sessions) == 1)
    }

    @Test func progressFractionReflectsPartialProgress() {
        let session = makeFinishedSession()
        for _ in 0..<5 {
            addProblem(session, grade: .green, sends: 1)
        }
        let tenSends = AchievementEngine.definitions.first { $0.id == "sends-10" }!
        #expect(abs(tenSends.progressFraction(in: [session]) - 0.5) < 0.001)
    }
}
