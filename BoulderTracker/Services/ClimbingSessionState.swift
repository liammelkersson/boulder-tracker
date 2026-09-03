import Foundation

/// Builds the Live Activity payload from a session. Kept apart from
/// `SessionActivityPresenter` so the contents are testable without ActivityKit.
enum ClimbingSessionState {
    static func attributes(for session: Session) -> ClimbingSessionAttributes {
        ClimbingSessionAttributes(
            sessionSyncID: session.syncID ?? UUID(),
            gymName: session.gym?.name
        )
    }

    static func contentState(
        for session: Session, gradeSystem: GradeSystem
    ) -> ClimbingSessionAttributes.ContentState {
        let problems = session.problems
        return ClimbingSessionAttributes.ContentState(
            startTime: session.startTime,
            sendCount: problems.reduce(0) { $0 + $1.flashCount + $1.sendCount },
            tally: tally(of: problems),
            quickGrades: QuickLogGradeSelection.grades(for: problems),
            gradeSystem: gradeSystem
        )
    }

    private static func tally(of problems: [SessionProblem]) -> [GradeTally] {
        ColorGrade.displayOrder.compactMap { grade in
            let count = problems
                .filter { $0.colorGrade == grade }
                .reduce(0) { $0 + $1.totalLogs }
            return count > 0 ? GradeTally(grade: grade, count: count) : nil
        }
    }
}
