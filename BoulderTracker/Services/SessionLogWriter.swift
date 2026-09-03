import Foundation
import SwiftData

/// The store-facing half of `LogSendIntent`: the only conformer of
/// `SessionSendLogging`. A Lock Screen button lands here and follows the same
/// path as an in-app quick log — same problem, same sync event, same refresh.
@MainActor
final class SessionLogWriter: SessionSendLogging {
    private let context: ModelContext
    private let announceAttempt: (SessionProblem, Session, AttemptResult) -> Void
    private let refreshActivity: (Session) -> Void

    init(
        context: ModelContext,
        announceAttempt: @escaping (SessionProblem, Session, AttemptResult) -> Void,
        refreshActivity: @escaping (Session) -> Void
    ) {
        self.context = context
        self.announceAttempt = announceAttempt
        self.refreshActivity = refreshActivity
    }

    /// No live session means the Activity is already outliving its session;
    /// dropping the tap is better than inventing one to log against.
    func logSend(grade: ColorGrade) {
        guard let session = LiveSessionFetch.current(in: context) else { return }
        let problem = QuickLogEntry.problem(for: grade, in: session)
        problem.recordResult(.send)
        context.saveReportingFailure(operation: "lock screen send")
        announceAttempt(problem, session, .send)
        refreshActivity(session)
    }
}
