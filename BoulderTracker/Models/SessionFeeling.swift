import Foundation

enum SessionFeeling: String, Codable, CaseIterable, Identifiable {
    case great, good, tough

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }
}
