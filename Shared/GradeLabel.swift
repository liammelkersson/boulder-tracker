import Foundation

extension ColorGrade {
    /// Compact form for badges, pills, tallies, and watch rows, where a range
    /// would overflow the layout.
    func shortLabel(in system: GradeSystem) -> String {
        switch system {
        case .color: displayName
        case .french: frenchShort
        case .vScale: vGradeShort
        }
    }

    /// Fuller form for detail rows, which have room to be honest about the span
    /// a single colour covers.
    func detailLabel(in system: GradeSystem) -> String {
        switch system {
        case .color: "\(displayName) · \(frenchRange)"
        case .french: frenchRange
        case .vScale: vGradeRange
        }
    }
}
