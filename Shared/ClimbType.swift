import Foundation

enum ClimbType: String, Codable, CaseIterable, Identifiable {
    case bouldering, boulderingOutdoor, topRope, lead

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bouldering: "Bouldering"
        case .boulderingOutdoor: "Bouldering (Outdoor)"
        case .topRope: "Top Rope"
        case .lead: "Lead"
        }
    }
}
