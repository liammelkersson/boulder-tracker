import Foundation

/// How a grade is *named* in the UI. Purely presentational — the stored grade is
/// always a `ColorGrade`, so switching systems never migrates or reinterprets data.
enum GradeSystem: String, Codable, Sendable, CaseIterable, Identifiable {
    case color, french, vScale

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .color: "Colour"
        case .french: "Font"
        case .vScale: "V-scale"
        }
    }
}
