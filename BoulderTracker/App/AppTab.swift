import Foundation

enum AppTab: Hashable, CaseIterable {
    case climb, activities, startSession, profile

    var label: String {
        switch self {
        case .climb: "Climb"
        case .activities: "Activities"
        case .startSession: "Start"
        case .profile: "Profile"
        }
    }

    var symbolName: String {
        switch self {
        case .climb: "figure.climbing"
        case .activities: "calendar"
        case .startSession: "plus.circle.fill"
        case .profile: "person.crop.circle"
        }
    }

    /// Selecting this tab runs an action instead of showing a screen, so it
    /// never stays selected.
    var isAction: Bool { self == .startSession }
}
