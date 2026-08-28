import Foundation
import SwiftData

@Model
final class Session {
    var date: Date
    var startTime: Date
    var endTime: Date?
    var notes: String?
    var healthKitWorkoutID: UUID?
    var gym: Gym?
    var partners: [Partner]
    @Relationship(deleteRule: .cascade, inverse: \ProblemAttempt.session)
    var attempts: [ProblemAttempt]

    init(startTime: Date, gym: Gym?, partners: [Partner]) {
        self.date = startTime
        self.startTime = startTime
        self.endTime = nil
        self.gym = gym
        self.partners = partners
        self.attempts = []
    }

    var isLive: Bool { endTime == nil }

    var duration: TimeInterval {
        (endTime ?? startTime).timeIntervalSince(startTime)
    }
}
