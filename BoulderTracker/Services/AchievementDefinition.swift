import Foundation

struct AchievementDefinition: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbolName: String
    let isSatisfied: ([Session]) -> Bool
}
