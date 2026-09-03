import Foundation

/// Chooses the three grades the Lock Screen offers as quick-log buttons: the
/// ones worked most this session, so the buttons follow what the climber is
/// actually on. Pure, so the choice is testable without ActivityKit.
enum QuickLogGradeSelection {
    static let buttonCount = 3

    /// Shown before anything is logged, and used to pad a session that has
    /// worked fewer than three grades.
    static let fallbackGrades: [ColorGrade] = [.blue, .red, .black]

    static func grades(for problems: [SessionProblem]) -> [ColorGrade] {
        let ranked = ColorGrade.displayOrder
            .map { grade in (grade: grade, count: logCount(of: grade, in: problems)) }
            .filter { $0.count > 0 }
            // Stable sort on a display-ordered list, so equal counts keep
            // display order.
            .sorted { $0.count > $1.count }
            .map(\.grade)
        return padded(ranked)
    }

    private static func logCount(of grade: ColorGrade, in problems: [SessionProblem]) -> Int {
        problems
            .filter { $0.colorGrade == grade }
            .reduce(0) { $0 + $1.totalLogs }
    }

    private static func padded(_ grades: [ColorGrade]) -> [ColorGrade] {
        var selection = grades.prefix(buttonCount).map { $0 }
        for fallback in fallbackGrades where selection.count < buttonCount {
            if !selection.contains(fallback) {
                selection.append(fallback)
            }
        }
        for grade in ColorGrade.displayOrder where selection.count < buttonCount {
            if !selection.contains(grade) {
                selection.append(grade)
            }
        }
        return selection
    }
}
