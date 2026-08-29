import Foundation

enum WorkoutSaveResult {
    case saved
    case failed
    case syncDisabled
}

struct SessionCompletionOutcome: Identifiable {
    let id = UUID()
    let newAchievements: [AchievementDefinition]
    let workoutSave: WorkoutSaveResult
}
