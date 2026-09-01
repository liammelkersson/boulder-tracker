import Testing
import Foundation
import SwiftData
@testable import BoulderTracker

@MainActor
struct PhoneSyncCoordinatorTests {
    private func temporaryQueue() -> PendingEventQueue {
        PendingEventQueue(fileURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("phone-coordinator-\(UUID().uuidString).json"))
    }

    private func makeCoordinator(
        context: ModelContext, link: FakeSyncLink
    ) -> PhoneSyncCoordinator {
        PhoneSyncCoordinator(context: context, link: link, queue: temporaryQueue())
    }

    private func catalogPayloads(on link: FakeSyncLink) -> [PhoneCatalogPayload] {
        link.guaranteed.compactMap { envelope in
            guard case .phoneCatalog(let payload) = envelope.event else { return nil }
            return payload
        }
    }

    @Test func startActivatesLinkAndSendsCatalog() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        context.insert(Gym(name: "Klättervigören Jönköping", isDefault: true))
        try context.save()
        let link = FakeSyncLink()
        let coordinator = makeCoordinator(context: context, link: link)

        coordinator.start()

        #expect(link.isActivated)
        let catalog = catalogPayloads(on: link).first
        #expect(catalog?.gyms == [GymSnapshot(name: "Klättervigören Jönköping", isDefault: true)])
    }

    @Test func liveSessionRequestIsAnsweredWithLatestLiveSession() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let older = Session(startTime: Date(timeIntervalSince1970: 100), gym: nil, partners: [])
        older.endTime = Date(timeIntervalSince1970: 200)
        let live = Session(startTime: Date(timeIntervalSince1970: 300), gym: nil, partners: [])
        context.insert(older)
        context.insert(live)
        try context.save()
        let link = FakeSyncLink()
        let coordinator = makeCoordinator(context: context, link: link)
        coordinator.start()

        link.onReceive?(SyncEnvelope(event: .liveSessionRequest))

        let snapshots = link.guaranteed.compactMap { envelope -> SessionSnapshotPayload? in
            guard case .sessionSnapshot(let payload) = envelope.event else { return nil }
            return payload
        }
        #expect(snapshots.count == 1)
        #expect(snapshots.first?.liveSession?.sessionSyncID == live.syncID)
    }

    @Test func inboundEventsReachTheStore() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let link = FakeSyncLink()
        let coordinator = makeCoordinator(context: context, link: link)
        coordinator.start()
        let sessionSyncID = UUID()

        link.onReceive?(SyncEnvelope(event: .sessionStarted(SessionStartPayload(
            sessionSyncID: sessionSyncID, startTime: Date(timeIntervalSince1970: 400),
            gymName: nil, climbType: .bouldering
        ))))

        let stored = try context.fetch(FetchDescriptor<Session>())
        #expect(stored.first?.syncID == sessionSyncID)
        #expect(stored.first?.isWatchTracked == true)
    }

    @Test func announceAttemptSkipsSessionsWithoutSyncID() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let session = Session(startTime: .now, gym: nil, partners: [])
        session.syncID = nil
        let problem = SessionProblem(name: "", colorGrade: .red, styles: [])
        session.problems.append(problem)
        context.insert(session)
        try context.save()
        let link = FakeSyncLink()
        let coordinator = makeCoordinator(context: context, link: link)

        coordinator.announceAttempt(on: problem, in: session, result: .send)

        #expect(link.guaranteed.isEmpty)
    }
}
