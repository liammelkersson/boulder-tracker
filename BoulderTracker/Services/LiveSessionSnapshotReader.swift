import Foundation

/// Builds the absolute-state snapshot used only for watch cold-start catch-up.
/// A session that predates sync has no `syncID` and cannot be mirrored.
enum LiveSessionSnapshotReader {
    static func snapshot(of session: Session?) -> LiveSessionSnapshot? {
        guard let session, session.isLive, let sessionSyncID = session.syncID else { return nil }
        return LiveSessionSnapshot(
            sessionSyncID: sessionSyncID,
            startTime: session.startTime,
            gymName: session.gym?.name,
            climbType: session.climbType,
            problems: session.problems.compactMap(counts(of:))
        )
    }

    private static func counts(of problem: SessionProblem) -> ProblemCountsSnapshot? {
        guard let problemSyncID = problem.syncID else { return nil }
        return ProblemCountsSnapshot(
            problemSyncID: problemSyncID,
            colorGrade: problem.colorGrade,
            flashCount: problem.flashCount,
            sendCount: problem.sendCount,
            fallCount: problem.fallCount
        )
    }
}
