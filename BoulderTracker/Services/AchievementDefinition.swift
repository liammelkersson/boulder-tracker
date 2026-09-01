import Foundation

struct AchievementDefinition: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbolName: String
    let target: Int
    var iconStyle: AchievementIconStyle = .plasticHold
    let currentCount: ([Session]) -> Int

    func isSatisfied(by sessions: [Session]) -> Bool {
        currentCount(sessions) >= target
    }

    func progressFraction(in sessions: [Session]) -> Double {
        min(1, Double(currentCount(sessions)) / Double(target))
    }
}
