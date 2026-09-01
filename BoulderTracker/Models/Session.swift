import Foundation
import SwiftData

@Model
final class Session {
    var date: Date
    var startTime: Date
    var endTime: Date?
    var climbType: ClimbType
    var feeling: SessionFeeling?
    var notes: String?
    var photoFilename: String?
    var healthKitWorkoutID: UUID?
    /// Stable identity across devices. SwiftData's `PersistentIdentifier` is
    /// device-local, so sync needs its own key. Optional because rows migrated
    /// from before sync existed must stay unmatched rather than share a default.
    var syncID: UUID?
    var avgHeartRate: Double?
    var maxHeartRate: Double?
    var activeCalories: Double?
    /// True once any event from the watch touched this session; the phone then
    /// leaves the Health workout to the watch.
    var isWatchTracked: Bool = false
    /// Envelope ids already applied, making replayed deliveries no-ops.
    var appliedEventIDs: [UUID] = []
    /// Demo rows inserted by `SampleDataGenerator`; removed together when the
    /// sample-data toggle turns off.
    var isSampleData: Bool = false
    var gym: Gym?
    var shoe: Shoe?
    var partners: [Partner]
    @Relationship(deleteRule: .cascade, inverse: \SessionProblem.session)
    var problems: [SessionProblem]

    init(startTime: Date, gym: Gym?, partners: [Partner], climbType: ClimbType = .bouldering) {
        self.date = startTime
        self.startTime = startTime
        self.endTime = nil
        self.climbType = climbType
        self.gym = gym
        self.partners = partners
        self.problems = []
        self.syncID = UUID()
    }

    var isLive: Bool { endTime == nil }

    var duration: TimeInterval {
        (endTime ?? startTime).timeIntervalSince(startTime)
    }
}
