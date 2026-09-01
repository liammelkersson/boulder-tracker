import Foundation

/// How a grade is *numbered* in the UI. Purely presentational — the stored grade is
/// always a `ColorGrade`, so switching systems never migrates or reinterprets data.
/// The hold colour is not one of the choices: it is always shown as a swatch next to
/// the number, in both systems.
enum GradeSystem: String, Codable, Sendable, CaseIterable, Identifiable {
    case french, vScale

    /// Used when nothing is stored yet, and when a value written by an older build
    /// (`"color"`, back when colour was a third system) no longer decodes.
    static let `default` = GradeSystem.french

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .french: "Font"
        case .vScale: "V-scale"
        }
    }
}
