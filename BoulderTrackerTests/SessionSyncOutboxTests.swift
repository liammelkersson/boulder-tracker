import Testing
import Foundation
@testable import BoulderTracker

@MainActor
struct SessionSyncOutboxTests {
    private func temporaryQueue() -> PendingEventQueue {
        PendingEventQueue(fileURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("outbox-\(UUID().uuidString).json"))
    }

    private func endedEvent() -> SessionSyncEvent {
        .sessionEnded(SessionEndPayload(sessionSyncID: UUID(), endTime: .now))
    }

    @Test func reachablePeerGetsBothChannels() {
        let link = FakeSyncLink()
        let outbox = SessionSyncOutbox(queue: temporaryQueue(), link: link)

        outbox.send(endedEvent())

        #expect(link.immediate.count == 1)
        #expect(link.guaranteed.count == 1)
        #expect(link.immediate.first?.id == link.guaranteed.first?.id)
    }

    @Test func unreachablePeerGetsOnlyGuaranteedChannel() {
        let link = FakeSyncLink()
        link.isPeerReachable = false
        let outbox = SessionSyncOutbox(queue: temporaryQueue(), link: link)

        outbox.send(endedEvent())

        #expect(link.immediate.isEmpty)
        #expect(link.guaranteed.count == 1)
    }

    @Test func sentEventStaysPendingUntilDeliveryIsConfirmed() {
        let queue = temporaryQueue()
        let link = FakeSyncLink()
        let outbox = SessionSyncOutbox(queue: queue, link: link)

        outbox.send(endedEvent())
        #expect(queue.pending.count == 1)

        link.confirmDelivery(of: link.guaranteed[0])
        #expect(queue.pending.isEmpty)
    }

    @Test func resendPendingRedeliversEverythingUnconfirmed() {
        let queue = temporaryQueue()
        let link = FakeSyncLink()
        let outbox = SessionSyncOutbox(queue: queue, link: link)
        outbox.send(endedEvent())
        outbox.send(endedEvent())

        outbox.resendPending()

        #expect(link.guaranteed.count == 4)
        #expect(queue.pending.count == 2)
    }

    @Test func resendKeepsEnvelopeIdentitiesStable() {
        let queue = temporaryQueue()
        let link = FakeSyncLink()
        let outbox = SessionSyncOutbox(queue: queue, link: link)
        outbox.send(endedEvent())
        let originalID = link.guaranteed[0].id

        outbox.resendPending()

        #expect(link.guaranteed[1].id == originalID)
    }
}
