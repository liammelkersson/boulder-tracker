import Foundation

struct SessionStartPayload: Codable, Sendable, Equatable {
    let sessionSyncID: UUID
    let startTime: Date
    let gymName: String?
    let climbType: ClimbType
}

/// Carries the grade so a receiver that has never seen this problem can create it,
/// which removes any ordering requirement between logs within a session.
struct AttemptLogPayload: Codable, Sendable, Equatable {
    let sessionSyncID: UUID
    let problemSyncID: UUID
    let colorGrade: ColorGrade
    let result: AttemptResult
    let loggedAt: Date
}

struct SessionEndPayload: Codable, Sendable, Equatable {
    let sessionSyncID: UUID
    let endTime: Date
}

struct WorkoutSummaryPayload: Codable, Sendable, Equatable {
    let sessionSyncID: UUID
    let workoutID: UUID
    let avgHeartRate: Double?
    let maxHeartRate: Double?
    let activeCalories: Double?
}

struct ProblemCountsSnapshot: Codable, Sendable, Equatable {
    let problemSyncID: UUID
    let colorGrade: ColorGrade
    let flashCount: Int
    let sendCount: Int
    let fallCount: Int
}

struct LiveSessionSnapshot: Codable, Sendable, Equatable {
    let sessionSyncID: UUID
    let startTime: Date
    let gymName: String?
    let climbType: ClimbType
    let problems: [ProblemCountsSnapshot]
}

/// `liveSession` is nil when the responder has no session running.
struct SessionSnapshotPayload: Codable, Sendable, Equatable {
    let liveSession: LiveSessionSnapshot?
}

struct GymSnapshot: Codable, Sendable, Equatable {
    let name: String
    let isDefault: Bool
}

struct PhoneCatalogPayload: Codable, Sendable, Equatable {
    let gyms: [GymSnapshot]
    let healthKitSyncEnabled: Bool
    /// Optional so an envelope queued by an older build still decodes.
    let gradeSystem: GradeSystem?
}

/// Every mutation crosses the wire as an additive event. Increments commute, so a
/// two-way merge has no conflicts and replaying an event changes nothing.
enum SessionSyncEvent: Codable, Sendable, Equatable {
    case sessionStarted(SessionStartPayload)
    case attemptLogged(AttemptLogPayload)
    case sessionEnded(SessionEndPayload)
    case workoutRecorded(WorkoutSummaryPayload)
    case liveSessionRequest
    case sessionSnapshot(SessionSnapshotPayload)
    case phoneCatalog(PhoneCatalogPayload)
}
