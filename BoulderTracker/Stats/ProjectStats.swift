import Foundation

/// Attempt history of a project, read from the session problems linked to it.
/// The project row owns identity and status; sessions still own the logs.
struct ProjectStats {
    let sessionCount: Int
    let attemptCount: Int
    let lastAttemptDate: Date?

    init(project: Project) {
        let problems = (project.problems ?? []).persisted
        sessionCount = Set(problems.compactMap { $0.session?.persistentModelID }).count
        attemptCount = problems.reduce(0) { $0 + $1.totalLogs }
        lastAttemptDate = problems.compactMap { $0.session?.startTime }.max()
    }
}
