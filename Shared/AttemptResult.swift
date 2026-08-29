import Foundation

enum AttemptResult: String, Codable, CaseIterable, Identifiable {
    case flash, send, fall

    var id: String { rawValue }

    var countsAsSend: Bool { self != .fall }

    var displayName: String { rawValue.capitalized }
}
