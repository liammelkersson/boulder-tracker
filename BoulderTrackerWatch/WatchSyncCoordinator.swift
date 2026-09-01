import Foundation
import Observation
import OSLog

/// Owns the watch side: link, outbox, live session state, and the workout. UI calls
/// the four intent methods; everything else is event plumbing.
@MainActor
@Observable
final class WatchSyncCoordinator {
    let liveSession: WatchLiveSession
    let workout = LiveWorkoutSession()

    private(set) var gyms: [GymSnapshot] = []
    private(set) var gradeSystem: GradeSystem = .default
    private(set) var lastMetrics: WorkoutMetrics?
    private(set) var finishedDuration: TimeInterval?

    @ObservationIgnored private let link: any SyncLinking
    @ObservationIgnored private let outbox: SessionSyncOutbox
    @ObservationIgnored private var healthKitSyncEnabled = true

    init(link: any SyncLinking, queue: PendingEventQueue, liveSessionFileURL: URL) {
        liveSession = WatchLiveSession(fileURL: liveSessionFileURL)
        self.link = link
        outbox = SessionSyncOutbox(queue: queue, link: link)
    }

    convenience init() {
        self.init(
            link: WatchConnectivityLink(),
            queue: .inApplicationSupport(named: "watch-sync-queue.json"),
            liveSessionFileURL: Self.liveSessionFileURL()
        )
    }

    func start() {
        link.onReceive = { [weak self] envelope in self?.route(envelope) }
        link.activate()
        outbox.resendPending()
        if liveSession.snapshot == nil {
            outbox.send(.liveSessionRequest)
        }
    }

    func beginSession(gymName: String?, climbType: ClimbType) {
        let event = liveSession.startEvent(
            gymName: gymName, climbType: climbType, startTime: .now
        )
        liveSession.apply(event)
        outbox.send(event)
        startWorkout()
    }

    func log(grade: ColorGrade, result: AttemptResult) {
        let event = liveSession.attemptEvent(grade: grade, result: result, loggedAt: .now)
        liveSession.apply(event)
        outbox.send(event)
    }

    func finishSession() {
        guard let snapshot = liveSession.snapshot else { return }
        let endTime = Date.now
        finishedDuration = endTime.timeIntervalSince(snapshot.startTime)
        let event = liveSession.endEvent(endTime: endTime)
        liveSession.apply(event)
        outbox.send(event)
        finishWorkout(sessionSyncID: snapshot.sessionSyncID, endTime: endTime)
    }

    func dismissSummary() {
        finishedDuration = nil
        lastMetrics = nil
    }

    private func route(_ envelope: SyncEnvelope) {
        if case .phoneCatalog(let payload) = envelope.event {
            gyms = payload.gyms
            healthKitSyncEnabled = payload.healthKitSyncEnabled
            gradeSystem = payload.gradeSystem ?? .default
            return
        }
        liveSession.apply(envelope.event)
    }

    private func startWorkout() {
        guard healthKitSyncEnabled else { return }
        Task {
            do {
                try await workout.requestAuthorization()
                try await workout.begin(at: .now)
            } catch {
                // Logging continues without heart rate; the session itself is unaffected.
                Logger.health.error("Workout start failed, disabling HealthKit sync: \(error)")
                healthKitSyncEnabled = false
            }
        }
    }

    private func finishWorkout(sessionSyncID: UUID, endTime: Date) {
        guard healthKitSyncEnabled else { return }
        Task {
            do {
                try await workout.end(at: endTime)
            } catch {
                // The session-end event is already sent; only the summary is lost.
                Logger.health.error("Workout end failed: \(error)")
                return
            }
            guard let metrics = workout.metrics else { return }
            lastMetrics = metrics
            outbox.send(.workoutRecorded(WorkoutSummaryPayload(
                sessionSyncID: sessionSyncID,
                workoutID: metrics.workoutID,
                avgHeartRate: metrics.avgHeartRate,
                maxHeartRate: metrics.maxHeartRate,
                activeCalories: metrics.activeCalories
            )))
        }
    }

    private static func liveSessionFileURL() -> URL {
        let directory = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0]
        try? FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true
        )
        return directory.appendingPathComponent("watch-live-session.json")
    }
}
