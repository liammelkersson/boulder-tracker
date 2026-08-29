import Foundation

enum WorkoutSaveResult {
    case saved
    case failed
    case syncDisabled
    /// The watch ran the live workout and reported it; the phone must not write a second one.
    case recordedByWatch
}

struct SessionCompletionOutcome: Identifiable {
    let id = UUID()
    let newAchievements: [AchievementDefinition]
    let workoutSave: WorkoutSaveResult
}
