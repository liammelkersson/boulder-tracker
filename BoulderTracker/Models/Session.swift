import Foundation
import SwiftData

// Every attribute carries a default and every relationship is optional or
// defaulted: CloudKit-backed SwiftData stores require both.
@Model
final class Session {
    var date: Date = Date.now
    var startTime: Date = Date.now
    var endTime: Date?
    var climbType: ClimbType = ClimbType.bouldering
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
    // CloudKit-backed stores require optional to-many relationships;
    // `originalName` keeps the on-disk schema of the shipped non-optionals.
    @Relationship(originalName: "partners", inverse: \Partner.sessions)
    private var storedPartners: [Partner]? = []
    @Relationship(deleteRule: .cascade, originalName: "problems",
                  inverse: \SessionProblem.session)
    private var storedProblems: [SessionProblem]? = []

    var partners: [Partner] {
        get { storedPartners ?? [] }
        set { storedPartners = newValue }
    }

    var problems: [SessionProblem] {
        get { storedProblems ?? [] }
        set { storedProblems = newValue }
    }

    init(startTime: Date, gym: Gym?, partners: [Partner], climbType: ClimbType = .bouldering) {
        self.date = startTime
        self.startTime = startTime
        self.endTime = nil
        self.climbType = climbType
        self.gym = gym
        self.storedPartners = partners
        self.storedProblems = []
        self.syncID = UUID()
    }

    var isLive: Bool { endTime == nil }

    var duration: TimeInterval {
        (endTime ?? startTime).timeIntervalSince(startTime)
    }
}
