import Foundation
@testable import BoulderTracker

final class FakeWorkoutWriter: WorkoutWriting, @unchecked Sendable {
    private(set) var savedIntervals: [(start: Date, end: Date)] = []
    private(set) var deletedIDs: [UUID] = []
    let fixedWorkoutID = UUID()

    func requestAuthorization() async throws {}

    func saveClimbingWorkout(start: Date, end: Date) async throws -> UUID {
        savedIntervals.append((start, end))
        return fixedWorkoutID
    }

    func deleteClimbingWorkout(id: UUID) async throws {
        deletedIDs.append(id)
    }
}
