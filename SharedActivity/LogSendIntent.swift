import AppIntents
import Foundation

/// Logs a send from the Lock Screen. `LiveActivityIntent` performs in the
/// app's process, so this writes through the app's own container — no App
/// Group required.
struct LogSendIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Log a send"
    static let isDiscoverable = false

    @Parameter(title: "Grade")
    var gradeRawValue: Int

    init() {}

    init(grade: ColorGrade) {
        gradeRawValue = grade.rawValue
    }

    /// A missing writer is a no-op: the button must never crash the app, and
    /// the state it would have logged is not worth guessing at.
    @MainActor
    func perform() async throws -> some IntentResult {
        if let grade = ColorGrade(rawValue: gradeRawValue) {
            SessionSendLog.writer?.logSend(grade: grade)
        }
        return .result()
    }
}
