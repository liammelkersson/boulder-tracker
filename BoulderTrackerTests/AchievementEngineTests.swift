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
        session.attempts.append(ProblemAttempt(
            colorGrade: .black, styles: [], attemptCount: 4, result: .send
        ))
        let unlocked = AchievementEngine.newlyUnlocked(sessions: [session], alreadyUnlocked: [])
        #expect(unlocked.contains { $0.id == "first-send-black" })
        #expect(!unlocked.contains { $0.id == "first-send-yellow" })
    }

    @Test func marathonRequiresTwoHours() {
        let short = makeFinishedSession(hoursLong: 1.9)
        let long = makeFinishedSession(hoursLong: 2.1)
        #expect(!AchievementEngine.newlyUnlocked(sessions: [short], alreadyUnlocked: [])
            .contains { $0.id == "marathon" })
        #expect(AchievementEngine.newlyUnlocked(sessions: [long], alreadyUnlocked: [])
            .contains { $0.id == "marathon" })
    }

    @Test func nightOwlRequiresEndAfterNine() {
        let evening = makeFinishedSession(endHour: 22)
        let unlocked = AchievementEngine.newlyUnlocked(sessions: [evening], alreadyUnlocked: [])
        #expect(unlocked.contains { $0.id == "night-owl" })
    }

    @Test func flashTenBluesUnlocks() {
        let session = makeFinishedSession()
        for _ in 0..<10 {
            session.attempts.append(ProblemAttempt(
                colorGrade: .blue, styles: [], attemptCount: 1, result: .flash
            ))
        }
        let unlocked = AchievementEngine.newlyUnlocked(sessions: [session], alreadyUnlocked: [])
        #expect(unlocked.contains { $0.id == "flash-10-blues" })
    }

    @Test func fiveStylesRequiresSendsInFiveDistinctStyles() {
        let session = makeFinishedSession()
        let styles: [RouteStyle] = [.dyno, .sloper, .crimp, .overhang, .slab]
        for style in styles {
            session.attempts.append(ProblemAttempt(
                colorGrade: .green, styles: [style], attemptCount: 1, result: .send
            ))
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
}
