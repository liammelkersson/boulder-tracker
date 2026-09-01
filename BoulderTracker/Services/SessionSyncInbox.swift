import Foundation
import SwiftData

/// Applies sync events from the watch into the phone's store. Every event is
/// idempotent: replaying an envelope leaves the store unchanged. Events that name
/// an unknown session are buffered and replayed when that session arrives.
@MainActor
final class SessionSyncInbox {
    private let context: ModelContext
    private var orphansBySession: [UUID: [SyncEnvelope]] = [:]

    init(context: ModelContext) {
        self.context = context
    }

    func apply(_ envelope: SyncEnvelope) {
        switch envelope.event {
        case .sessionStarted(let payload):
            adoptSession(payload)
        case .attemptLogged(let payload):
            recordAttempt(payload, from: envelope)
        case .sessionEnded(let payload):
            closeSession(payload)
        case .workoutRecorded(let payload):
            attachWorkout(payload)
        case .liveSessionRequest, .sessionSnapshot, .phoneCatalog, .sessionDeleted:
            // Answered by PhoneSyncCoordinator or consumed only on the watch;
            // the watch has no delete UI, so inbound deletes carry nothing.
            break
        }
        context.saveReportingFailure(operation: "sync inbox apply")
    }

    private func adoptSession(_ payload: SessionStartPayload) {
        guard session(with: payload.sessionSyncID) == nil else { return }
        let session = Session(
            startTime: payload.startTime,
            gym: gym(named: payload.gymName),
            partners: [],
            climbType: payload.climbType
        )
        session.syncID = payload.sessionSyncID
        session.isWatchTracked = true
        context.insert(session)
        closeAllButLatestLiveSession()
        replayOrphans(of: payload.sessionSyncID)
    }

    /// Two devices can each start a session before either hears about the
    /// other. Only the latest-starting session stays live; earlier ones are
    /// closed at the moment the newer one began.
    private func closeAllButLatestLiveSession() {
        let descriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.endTime == nil })
        let liveSessions = ((try? context.fetch(descriptor)) ?? [])
            .sorted { $0.startTime < $1.startTime }
        guard let newest = liveSessions.last else { return }
        for stale in liveSessions.dropLast() {
            stale.endTime = max(stale.startTime, newest.startTime)
        }
    }

    private func recordAttempt(_ payload: AttemptLogPayload, from envelope: SyncEnvelope) {
        guard let session = session(with: payload.sessionSyncID) else {
            orphansBySession[payload.sessionSyncID, default: []].append(envelope)
            return
        }
        guard !session.appliedEventIDs.contains(envelope.id) else { return }
        let problem = session.problems.first { $0.syncID == payload.problemSyncID }
            ?? insertProblem(payload, into: session)
        problem.recordResult(payload.result)
        session.appliedEventIDs.append(envelope.id)
        session.isWatchTracked = true
    }

    private func closeSession(_ payload: SessionEndPayload) {
        guard let session = session(with: payload.sessionSyncID) else { return }
        session.endTime = payload.endTime
    }

    private func attachWorkout(_ payload: WorkoutSummaryPayload) {
        guard let session = session(with: payload.sessionSyncID) else { return }
        session.healthKitWorkoutID = payload.workoutID
        session.avgHeartRate = payload.avgHeartRate
        session.maxHeartRate = payload.maxHeartRate
        session.activeCalories = payload.activeCalories
        session.isWatchTracked = true
    }

    private func replayOrphans(of sessionSyncID: UUID) {
        let buffered = orphansBySession.removeValue(forKey: sessionSyncID) ?? []
        for envelope in buffered {
            guard case .attemptLogged(let payload) = envelope.event else { continue }
            recordAttempt(payload, from: envelope)
        }
    }

    private func insertProblem(
        _ payload: AttemptLogPayload, into session: Session
    ) -> SessionProblem {
        let problem = SessionProblem(name: "", colorGrade: payload.colorGrade, styles: [])
        problem.syncID = payload.problemSyncID
        session.problems.append(problem)
        return problem
    }

    private func session(with syncID: UUID) -> Session? {
        let wanted: UUID? = syncID
        let descriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.syncID == wanted })
        return try? context.fetch(descriptor).first
    }

    private func gym(named name: String?) -> Gym? {
        guard let name else { return nil }
        let descriptor = FetchDescriptor<Gym>(predicate: #Predicate { $0.name == name })
        return try? context.fetch(descriptor).first
    }
}
