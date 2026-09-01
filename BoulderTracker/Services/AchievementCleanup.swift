import Foundation
import OSLog
import SwiftData

/// One-time repair: earlier builds let demo sample data unlock real,
/// permanent `Achievement` rows. Drops every stored row the real session
/// history cannot justify; legitimately earned ones re-unlock on the next
/// session save, and the grid recomputes live, so nothing truly earned
/// disappears from view.
enum AchievementCleanup {
    static let completedFlagKey = "pref.achievementCleanupDone"

    /// Achievements whose check depends on "now" (current weekly streak): an
    /// old unlock can be legitimate even when the check fails today, so
    /// stored rows for these are never removed.
    static let timeSensitiveIDs: Set<String> = ["weekly-streak-5"]

    static func removeUnearnedOnce(context: ModelContext, defaults: UserDefaults) {
        guard !defaults.bool(forKey: completedFlagKey) else { return }
        do {
            try removeUnearned(from: context)
            defaults.set(true, forKey: completedFlagKey)
        } catch {
            // Retried on next launch because the flag stays unset.
            Logger.persistence.error("Achievement cleanup failed: \(error)")
        }
    }

    static func removeUnearned(from context: ModelContext) throws {
        let realSessions = try context.fetch(FetchDescriptor<Session>())
            .withoutSampleData
            .filter { !$0.isLive }
        let earnedIDs = Set(
            AchievementEngine.definitions
                .filter { $0.isSatisfied(by: realSessions) }
                .map(\.id)
        )
        let keptIDs = earnedIDs.union(timeSensitiveIDs)
        let records = try context.fetch(FetchDescriptor<Achievement>())
        for record in records where !keptIDs.contains(record.achievementID) {
            Logger.persistence.notice("Removing unearned achievement \(record.achievementID)")
            context.delete(record)
        }
        try context.save()
    }
}
