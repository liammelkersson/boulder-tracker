import Foundation

/// Sends events over both WatchConnectivity channels and keeps them queued until
/// the guaranteed channel confirms delivery. Duplicate arrival is harmless because
/// receivers de-duplicate on envelope id.
@MainActor
final class SessionSyncOutbox {
    private let queue: PendingEventQueue
    private let link: SyncLinking

    init(queue: PendingEventQueue, link: SyncLinking) {
        self.queue = queue
        self.link = link
        link.onDelivered = { [weak queue] deliveredID in
            queue?.remove(deliveredID: deliveredID)
        }
        // Anything still pending gets another try whenever the transport
        // comes back (activation completes or the peer becomes reachable).
        link.onLinkReady = { [weak self] in
            self?.resendPending()
        }
    }

    func send(_ event: SessionSyncEvent) {
        let envelope = SyncEnvelope(event: event)
        queue.append(envelope)
        deliver(envelope)
    }

    func resendPending() {
        for envelope in queue.pending {
            deliver(envelope)
        }
    }

    private func deliver(_ envelope: SyncEnvelope) {
        if link.isPeerReachable {
            link.sendImmediately(envelope)
        }
        link.transferGuaranteed(envelope)
    }
}
