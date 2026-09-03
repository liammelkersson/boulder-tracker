import Foundation

/// Lifecycle of a climbing project. `archived` hides a project the user is
/// done with — a reset wall, a lost interest — without touching the attempts
/// logged against it.
enum ProjectStatus: String, Codable, CaseIterable, Identifiable {
    case active
    case sent
    case archived

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .active: "Active"
        case .sent: "Sent"
        case .archived: "Archived"
        }
    }
}
