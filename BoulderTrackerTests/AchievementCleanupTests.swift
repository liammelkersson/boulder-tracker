import Testing
import Foundation
import SwiftData
@testable import BoulderTracker

@MainActor
struct AchievementCleanupTests {
    private func achievementIDs(in context: ModelContext) throws -> Set<String> {
        Set(try context.fetch(FetchDescriptor<Achievement>()).map(\.achievementID))
    }

    private func insertFinishedSession(into context: ModelContext) {
        let session = Session(startTime: Date(timeIntervalSince1970: 1000), gym: nil, partners: [])
        session.endTime = Date(timeIntervalSince1970: 5000)
        context.insert(session)
    }

    @Test func unearnedAchievementsAreRemovedAndEarnedOnesKept() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        insertFinishedSession(into: context)
        context.insert(Achievement(achievementID: "first-session"))
        context.insert(Achievement(achievementID: "sends-500"))
        try context.save()

        try AchievementCleanup.removeUnearned(from: context)

        let remaining = try achievementIDs(in: context)
        #expect(remaining.contains("first-session"))
        #expect(!remaining.contains("sends-500"))
    }

    @Test func sampleDataCannotJustifyAnAchievement() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        try SampleDataGenerator.insertSampleData(into: context, referenceDate: .now)
        context.insert(Achievement(achievementID: "first-session"))
        try context.save()

        try AchievementCleanup.removeUnearned(from: context)

        #expect(try achievementIDs(in: context).isEmpty)
    }

    @Test func timeSensitiveAchievementsAreNeverRemoved() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        context.insert(Achievement(achievementID: "weekly-streak-5"))
        try context.save()

        try AchievementCleanup.removeUnearned(from: context)

        #expect(try achievementIDs(in: context).contains("weekly-streak-5"))
    }

    @Test func cleanupRunsOnlyOnce() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let suiteName = "cleanup-test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        AchievementCleanup.removeUnearnedOnce(context: context, defaults: defaults)
        #expect(defaults.bool(forKey: AchievementCleanup.completedFlagKey))

        context.insert(Achievement(achievementID: "sends-500"))
        try context.save()
        AchievementCleanup.removeUnearnedOnce(context: context, defaults: defaults)

        #expect(try achievementIDs(in: context).contains("sends-500"))
    }
}

@MainActor
struct OutdoorAchievementTests {
    @Test func outdoorSessionUnlocksOutdoorFirst() {
        let outdoor = Session(
            startTime: .now, gym: nil, partners: [], climbType: .boulderingOutdoor
        )
        outdoor.endTime = .now

        let unlocked = AchievementEngine.newlyUnlocked(
            sessions: [outdoor], alreadyUnlocked: []
        )

        #expect(unlocked.contains { $0.id == "outdoor-first" })
        #expect(!unlocked.contains { $0.id == "outdoor-5" })
    }

    @Test func indoorSessionsDoNotCountTowardOutdoorAchievements() {
        let indoor = Session(startTime: .now, gym: nil, partners: [])
        indoor.endTime = .now

        let unlocked = AchievementEngine.newlyUnlocked(
            sessions: [indoor], alreadyUnlocked: []
        )

        #expect(!unlocked.contains { $0.id.hasPrefix("outdoor") })
    }

    @Test func outdoorAchievementsUseTheMountainIcon() {
        let outdoorStyles = AchievementEngine.definitions
            .filter { $0.id.hasPrefix("outdoor") }
            .map(\.iconStyle)

        #expect(outdoorStyles.count == 2)
        #expect(outdoorStyles.allSatisfy { $0 == .outdoorMountain })
    }
}
