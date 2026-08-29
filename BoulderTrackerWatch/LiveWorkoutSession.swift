import Foundation
import HealthKit
import Observation

enum LiveWorkoutFailure: Error {
    case healthDataUnavailable
    case builderMissing
    case workoutMissing
}

/// Runs the real `HKWorkoutSession` on the watch, which is what earns live heart
/// rate, calories, and activity-ring credit. `end(at:)` populates `metrics`.
@MainActor
@Observable
final class LiveWorkoutSession: NSObject {
    private(set) var currentHeartRate: Double?
    private(set) var metrics: WorkoutMetrics?

    @ObservationIgnored private let store = HKHealthStore()
    @ObservationIgnored private var session: HKWorkoutSession?
    @ObservationIgnored private var builder: HKLiveWorkoutBuilder?

    private let heartRateType = HKQuantityType(.heartRate)
    private let activeEnergyType = HKQuantityType(.activeEnergyBurned)

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw LiveWorkoutFailure.healthDataUnavailable
        }
        try await store.requestAuthorization(
            toShare: [HKObjectType.workoutType(), activeEnergyType],
            read: [heartRateType, activeEnergyType]
        )
    }

    func begin(at startTime: Date) async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw LiveWorkoutFailure.healthDataUnavailable
        }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .climbing
        configuration.locationType = .indoor

        let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(
            healthStore: store, workoutConfiguration: configuration
        )
        builder.delegate = self
        session.delegate = self

        self.session = session
        self.builder = builder

        session.startActivity(with: startTime)
        try await builder.beginCollection(at: startTime)
    }

    func end(at endTime: Date) async throws {
        guard let session, let builder else { throw LiveWorkoutFailure.builderMissing }
        session.end()
        try await builder.endCollection(at: endTime)
        let summary = statisticsSummary(from: builder)
        guard let workout = try await builder.finishWorkout() else {
            throw LiveWorkoutFailure.workoutMissing
        }
        metrics = WorkoutMetrics(
            workoutID: workout.uuid,
            avgHeartRate: summary.average,
            maxHeartRate: summary.maximum,
            activeCalories: summary.calories
        )
        self.session = nil
        self.builder = nil
    }

    /// Must run before `finishWorkout()` — the builder's statistics are gone afterwards.
    private func statisticsSummary(
        from builder: HKLiveWorkoutBuilder
    ) -> (average: Double?, maximum: Double?, calories: Double?) {
        let beatsPerMinute = HKUnit.count().unitDivided(by: .minute())
        let heartRate = builder.statistics(for: heartRateType)
        let energy = builder.statistics(for: activeEnergyType)
        return (
            heartRate?.averageQuantity()?.doubleValue(for: beatsPerMinute),
            heartRate?.maximumQuantity()?.doubleValue(for: beatsPerMinute),
            energy?.sumQuantity()?.doubleValue(for: .kilocalorie())
        )
    }

    fileprivate func refreshHeartRate(from statistics: HKStatistics?) {
        let beatsPerMinute = HKUnit.count().unitDivided(by: .minute())
        currentHeartRate = statistics?.mostRecentQuantity()?.doubleValue(for: beatsPerMinute)
    }
}

extension LiveWorkoutSession: @preconcurrency HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        guard collectedTypes.contains(HKQuantityType(.heartRate)) else { return }
        let statistics = workoutBuilder.statistics(for: HKQuantityType(.heartRate))
        Task { @MainActor in self.refreshHeartRate(from: statistics) }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}

extension LiveWorkoutSession: @preconcurrency HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState, date: Date
    ) {}

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession, didFailWithError error: Error
    ) {}
}
