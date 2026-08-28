import Foundation

enum ColorGrade: Int, Codable, CaseIterable, Comparable, Identifiable {
    case green, blue, red, black, white, yellow

    var id: Int { rawValue }

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
        }
    }

    var frenchRange: String {
        switch self {
        case .green: "4–5b"
        case .blue: "5b–6a"
        case .red: "6a–6c"
        case .black: "6c–7a"
        case .white: "7b–7c"
        case .yellow: "8a+"
        }
    }

    var vGradeRange: String {
        switch self {
        case .green: "V0–V1"
        case .blue: "V1–V3"
        case .red: "V3–V5"
        case .black: "V5–V7"
        case .white: "V8–V10"
        case .yellow: "V11+"
        }
    }
}
