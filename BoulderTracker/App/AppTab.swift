import Foundation

enum AppTab: Hashable, CaseIterable {
    case climb, activities, stats, profile

    var label: String {
        switch self {
        case .climb: "Climb"
        case .activities: "Activities"
        case .stats: "Stats"
        case .profile: "Profile"
        }
    }

    var symbolName: String {
        switch self {
        case .climb: "figure.climbing"
        case .activities: "calendar"
        case .stats: "chart.bar.xaxis"
        case .profile: "person.crop.circle"
        }
    }
}
