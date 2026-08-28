import Foundation

struct SessionCompletion {
    private let workoutWriter: WorkoutWriting

    init(workoutWriter: WorkoutWriting) {
        self.workoutWriter = workoutWriter
    }

    @MainActor
    func finish(_ session: Session, endTime: Date, allSessions: [Session],
                unlockedIDs: Set<String>) async -> SessionCompletionOutcome {
        session.endTime = endTime
        let workoutSaved = await saveWorkout(for: session)
        let newAchievements = AchievementEngine.newlyUnlocked(
            sessions: allSessions, alreadyUnlocked: unlockedIDs
        )
        return SessionCompletionOutcome(
            newAchievements: newAchievements, workoutSaved: workoutSaved
        )
    }

    @MainActor
    func deleteWorkoutIfPresent(for session: Session) async {
        guard let workoutID = session.healthKitWorkoutID else { return }
        do {
            try await workoutWriter.deleteClimbingWorkout(id: workoutID)
        } catch {
            // Best-effort: local delete proceeds even when Health is unreachable.
            session.healthKitWorkoutID = nil
        }
    }

    @MainActor
    private func saveWorkout(for session: Session) async -> Bool {
        guard let end = session.endTime else { return false }
        do {
            let workoutID = try await workoutWriter.saveClimbingWorkout(
                start: session.startTime, end: end
            )
            session.healthKitWorkoutID = workoutID
            return true
        } catch {
            return false
        }
    }
}
