import Foundation

enum ColorGrade: Int, Codable, CaseIterable, Comparable, Identifiable {
    case unknown = -1
    case yellow = 0
    case green = 1
    case blue = 2
    case red = 3
    case black = 4
    case white = 5

    var id: Int { rawValue }

    /// Order used in pickers, tallies, and the grades reference table.
    static let displayOrder: [ColorGrade] = [.green, .blue, .red, .black, .white, .yellow, .unknown]

    static func < (lhs: ColorGrade, rhs: ColorGrade) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .green: "Green"
        case .blue: "Blue"
        case .red: "Red"
        case .black: "Black"
        case .white: "White"
        case .yellow: "Yellow"
        case .unknown: "Unknown"
        }
    }

    var frenchRange: String {
        switch self {
        case .yellow: "<4"
        case .green: "4–5"
        case .blue: "5+–6A"
        case .red: "6B–6C"
        case .black: "7A–7B"
        case .white: "7C+"
        case .unknown: "?"
        }
    }

    var vGradeRange: String {
        switch self {
        case .yellow: "–"
        case .green: "V0–V2"
        case .blue: "V3–V4"
        case .red: "V5–V6"
        case .black: "V7–V8"
        case .white: "V9+"
        case .unknown: "?"
        }
    }

    var vGradeShort: String {
        switch self {
        case .yellow: "WU"
        case .green: "V1"
        case .blue: "V3"
        case .red: "V5"
        case .black: "V7"
        case .white: "V9"
        case .unknown: "?"
        }
    }
}
