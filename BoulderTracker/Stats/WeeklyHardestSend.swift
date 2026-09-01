import Foundation

/// The toughest grade sent during one calendar week.
struct WeeklyHardestSend: Equatable {
    let weekStart: Date
    let grade: ColorGrade
}
