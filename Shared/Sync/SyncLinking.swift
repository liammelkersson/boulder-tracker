import Foundation

/// The transport seam. `WatchConnectivityLink` is the only production conformer;
/// tests drive the outbox through a fake.
@MainActor
protocol SyncLinking: AnyObject {
    /// True when the peer can receive a low-latency message right now.
    var isPeerReachable: Bool { get }
    /// Called with an envelope id once guaranteed delivery has completed.
    var onDelivered: ((UUID) -> Void)? { get set }
    /// Called for every envelope arriving from the peer, duplicates included.
    var onReceive: ((SyncEnvelope) -> Void)? { get set }

    func sendImmediately(_ envelope: SyncEnvelope)
    func transferGuaranteed(_ envelope: SyncEnvelope)
}
