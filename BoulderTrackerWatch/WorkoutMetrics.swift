import Foundation

struct WorkoutMetrics: Sendable, Equatable {
    let workoutID: UUID
    let avgHeartRate: Double?
    let maxHeartRate: Double?
    let activeCalories: Double?
}
