import Foundation

struct SessionCompletionOutcome: Identifiable {
    let id = UUID()
    let newAchievements: [AchievementDefinition]
    let workoutSaved: Bool
}
