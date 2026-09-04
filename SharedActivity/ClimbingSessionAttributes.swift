import ActivityKit
import Foundation

/// Everything the Lock Screen and Dynamic Island render for a live session.
///
/// Compiled into the app and the widget extension. It must stay free of
/// SwiftData: the extension has no store, and on this signing team no App
/// Group exists to share one.
struct ClimbingSessionAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let startTime: Date
        let sendCount: Int
        let tally: [GradeTally]
        let quickGrades: [ColorGrade]
        /// Travels in the state because the extension cannot read the app's
        /// `@AppStorage` preference; without it the Lock Screen would ignore
        /// the grade system the user picked.
        let gradeSystem: GradeSystem
    }

    let sessionSyncID: UUID
    let gymName: String?
}

struct GradeTally: Codable, Hashable {
    let grade: ColorGrade
    let count: Int
}
