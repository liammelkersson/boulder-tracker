import Testing
import Foundation
@testable import BoulderTrackerWatch

@MainActor
struct WatchSyncCoordinatorTests {
    private func temporaryURL(_ prefix: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString).json")
    }

    private func makeCoordinator(link: WatchFakeSyncLink) -> WatchSyncCoordinator {
        WatchSyncCoordinator(
            link: link,
            queue: PendingEventQueue(fileURL: temporaryURL("queue")),
            liveSessionFileURL: temporaryURL("live"),
            appliedEnvelopesFileURL: temporaryURL("applied")
        )
    }

    @Test func coldStartWithNoSessionRequestsTheLiveSession() {
        let link = WatchFakeSyncLink()
        let coordinator = makeCoordinator(link: link)

        coordinator.start()

        #expect(link.isActivated)
        #expect(link.guaranteed.contains { envelope in
            if case .liveSessionRequest = envelope.event { return true }
            return false
        })
    }

    @Test func phoneCatalogUpdatesGymsAndGradeSystem() {
        let link = WatchFakeSyncLink()
        let coordinator = makeCoordinator(link: link)
        coordinator.start()

        link.onReceive?(SyncEnvelope(event: .phoneCatalog(PhoneCatalogPayload(
            gyms: [GymSnapshot(name: "Klättervigören Jönköping", isDefault: true)],
            healthKitSyncEnabled: false,
            gradeSystem: .vScale
        ))))

        #expect(coordinator.gyms.count == 1)
        #expect(coordinator.gradeSystem == .vScale)
    }

    @Test func duplicateEnvelopeIsAppliedOnlyOnce() {
        let link = WatchFakeSyncLink()
        let coordinator = makeCoordinator(link: link)
        coordinator.start()
        coordinator.beginSession(gymName: nil, climbType: .bouldering)
        guard let sessionSyncID = coordinator.liveSession.snapshot?.sessionSyncID else {
            Issue.record("no live session")
            return
        }
        let envelope = SyncEnvelope(event: .attemptLogged(AttemptLogPayload(
            sessionSyncID: sessionSyncID, problemSyncID: UUID(),
            colorGrade: .red, result: .send, loggedAt: .now
        )))

        link.onReceive?(envelope)
        link.onReceive?(envelope)

        #expect(coordinator.liveSession.tally.first { $0.grade == .red }?.count == 1)
    }

    @Test func logSendsTheAttemptToThePhone() {
        let link = WatchFakeSyncLink()
        let coordinator = makeCoordinator(link: link)
        coordinator.start()
        coordinator.beginSession(gymName: nil, climbType: .bouldering)

        coordinator.log(grade: .black, result: .flash)

        #expect(link.guaranteed.contains { envelope in
            if case .attemptLogged(let payload) = envelope.event {
                return payload.colorGrade == .black && payload.result == .flash
            }
            return false
        })
        #expect(coordinator.liveSession.tally.first { $0.grade == .black }?.count == 1)
    }
}
