import Foundation

protocol WorkoutWriting: Sendable {
    func requestAuthorization() async throws
    func saveClimbingWorkout(start: Date, end: Date) async throws -> UUID
    func deleteClimbingWorkout(id: UUID) async throws
}
