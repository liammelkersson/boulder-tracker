import Foundation
import HealthKit

final class HealthKitWorkoutWriter: WorkoutWriting {
    private let store = HKHealthStore()

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try await store.requestAuthorization(
            toShare: [HKObjectType.workoutType()], read: []
        )
    }

    func saveClimbingWorkout(start: Date, end: Date) async throws -> UUID {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .climbing
        configuration.locationType = .indoor
        let builder = HKWorkoutBuilder(
            healthStore: store, configuration: configuration, device: .local()
        )
        try await builder.beginCollection(at: start)
        try await builder.endCollection(at: end)
        guard let workout = try await builder.finishWorkout() else {
            throw WorkoutWriteFailure.builderReturnedNoWorkout
        }
        return workout.uuid
    }

    func deleteClimbingWorkout(id: UUID) async throws {
        let predicate = HKQuery.predicateForObject(with: id)
        let samples = try await queryWorkouts(matching: predicate)
        guard let workout = samples.first else { return }
        try await store.delete(workout)
    }

    private func queryWorkouts(matching predicate: NSPredicate) async throws -> [HKSample] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(), predicate: predicate,
                limit: 1, sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples ?? [])
                }
            }
            store.execute(query)
        }
    }
}

enum WorkoutWriteFailure: Error {
    case builderReturnedNoWorkout
}
