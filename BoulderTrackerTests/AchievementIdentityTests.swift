import Testing
import Foundation
@testable import BoulderTracker

/// Achievement ids are persisted in `unlockedIDs`. They are built from colour
/// names and must never follow the display setting, or switching grade system
/// would orphan every unlocked achievement.
struct AchievementIdentityTests {
    @Test func gradeAchievementIDsUseColourNames() {
        let ids = Set(AchievementEngine.definitions.map(\.id))

        #expect(ids.contains("first-send-red"))
        #expect(ids.contains("first-send-black"))
        #expect(!ids.contains { $0.hasPrefix("first-send-v") })
        #expect(!ids.contains { $0.contains("6b") })
    }
}
