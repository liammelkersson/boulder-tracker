import Foundation
import SwiftData

/// Owns the phone side of the watch link: routes inbound events to the inbox,
/// answers the watch's cold-start request, and publishes phone-side logging so the
/// watch tally stays in step.
@MainActor
@Observable
final class PhoneSyncCoordinator {
    private let context: ModelContext
    private let inbox: SessionSyncInbox
    private let outbox: SessionSyncOutbox
    private let link: WatchConnectivityLink

    init(context: ModelContext) {
        self.context = context
        self.inbox = SessionSyncInbox(context: context)
        self.link = WatchConnectivityLink()
        self.outbox = SessionSyncOutbox(
            queue: .inApplicationSupport(named: "phone-sync-queue.json"), link: link
        )
    }

    func start() {
        link.onReceive = { [weak self] envelope in self?.route(envelope) }
        link.activate()
        outbox.resendPending()
        sendCatalog()
    }

    func announceStart(of session: Session) {
        guard let sessionSyncID = session.syncID else { return }
        outbox.send(.sessionStarted(SessionStartPayload(
            sessionSyncID: sessionSyncID,
            startTime: session.startTime,
            gymName: session.gym?.name,
            climbType: session.climbType
        )))
    }

    func announceAttempt(
        on problem: SessionProblem, in session: Session, result: AttemptResult
    ) {
        guard let sessionSyncID = session.syncID, let problemSyncID = problem.syncID else {
            return
        }
        outbox.send(.attemptLogged(AttemptLogPayload(
            sessionSyncID: sessionSyncID,
            problemSyncID: problemSyncID,
            colorGrade: problem.colorGrade,
            result: result,
            loggedAt: .now
        )))
    }

    func announceEnd(of session: Session) {
        guard let sessionSyncID = session.syncID, let endTime = session.endTime else { return }
        outbox.send(.sessionEnded(SessionEndPayload(
            sessionSyncID: sessionSyncID, endTime: endTime
        )))
    }

    private func route(_ envelope: SyncEnvelope) {
        if case .liveSessionRequest = envelope.event {
            answerLiveSessionRequest()
            return
        }
        inbox.apply(envelope)
    }

    private func answerLiveSessionRequest() {
        let live = (try? context.fetch(FetchDescriptor<Session>()))?.first { $0.isLive }
        outbox.send(.sessionSnapshot(SessionSnapshotPayload(
            liveSession: LiveSessionSnapshotReader.snapshot(of: live)
        )))
        sendCatalog()
    }

    private func sendCatalog() {
        let gyms = (try? context.fetch(FetchDescriptor<Gym>())) ?? []
        let healthKitSyncEnabled = UserDefaults.standard
            .object(forKey: AppPreferences.healthKitSyncKey) as? Bool ?? true
        let storedSystem = UserDefaults.standard.string(forKey: AppPreferences.gradeSystemKey)
        outbox.send(.phoneCatalog(PhoneCatalogPayload(
            gyms: gyms.map { GymSnapshot(name: $0.name, isDefault: $0.isDefault) },
            healthKitSyncEnabled: healthKitSyncEnabled,
            gradeSystem: storedSystem.flatMap(GradeSystem.init(rawValue:)) ?? .color
        )))
    }
}
