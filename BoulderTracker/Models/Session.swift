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
    var gym: Gym?
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
    }

    var isLive: Bool { endTime == nil }

    var duration: TimeInterval {
        (endTime ?? startTime).timeIntervalSince(startTime)
    }
}
