import Foundation

enum AttemptResult: String, Codable, CaseIterable, Identifiable {
    case flash, send, project

    var id: String { rawValue }

    var countsAsSend: Bool { self != .project }

    var displayName: String { rawValue.capitalized }
}
