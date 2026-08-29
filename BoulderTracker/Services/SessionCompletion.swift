import Foundation

struct SessionCompletion {
    /// `nil` means HealthKit sync is turned off in preferences.
    private let workoutWriter: WorkoutWriting?

    init(workoutWriter: WorkoutWriting?) {
        self.workoutWriter = workoutWriter
    }

    @MainActor
    func finish(_ session: Session, endTime: Date, allSessions: [Session],
                unlockedIDs: Set<String>) async -> SessionCompletionOutcome {
        session.endTime = endTime
        let workoutSave = await saveWorkout(for: session)
        let newAchievements = AchievementEngine.newlyUnlocked(
            sessions: allSessions, alreadyUnlocked: unlockedIDs
        )
        return SessionCompletionOutcome(
            newAchievements: newAchievements, workoutSave: workoutSave
        )
    }

    @MainActor
    func deleteWorkoutIfPresent(for session: Session) async {
        guard let workoutID = session.healthKitWorkoutID, let workoutWriter else { return }
        do {
            try await workoutWriter.deleteClimbingWorkout(id: workoutID)
        } catch {
            // Best-effort: local delete proceeds even when Health is unreachable.
            session.healthKitWorkoutID = nil
        }
    }

    @MainActor
    private func saveWorkout(for session: Session) async -> WorkoutSaveResult {
        guard let workoutWriter else { return .syncDisabled }
        guard let end = session.endTime else { return .failed }
        do {
            let workoutID = try await workoutWriter.saveClimbingWorkout(
                start: session.startTime, end: end
            )
            session.healthKitWorkoutID = workoutID
            return .saved
        } catch {
            return .failed
        }
    }
}
