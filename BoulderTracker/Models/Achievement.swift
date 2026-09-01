import Foundation
import SwiftData

@Model
final class Achievement {
    // No `.unique` constraint: CloudKit-backed stores reject them. The save
    // path already guards against duplicates via the unlocked-id set.
    var achievementID: String = ""
    var unlockedAt: Date = Date.now

    init(achievementID: String, unlockedAt: Date = .now) {
        self.achievementID = achievementID
        self.unlockedAt = unlockedAt
    }
}
