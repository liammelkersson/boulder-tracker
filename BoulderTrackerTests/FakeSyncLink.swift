import Foundation
@testable import BoulderTracker

@MainActor
final class FakeSyncLink: SyncLinking {
    var isPeerReachable = true
    var onDelivered: ((UUID) -> Void)?
    var onReceive: ((SyncEnvelope) -> Void)?
    var onLinkReady: (() -> Void)?
    private(set) var immediate: [SyncEnvelope] = []
    private(set) var guaranteed: [SyncEnvelope] = []
    private(set) var isActivated = false

    func activate() {
        isActivated = true
    }

    func sendImmediately(_ envelope: SyncEnvelope) {
        immediate.append(envelope)
    }

    func transferGuaranteed(_ envelope: SyncEnvelope) {
        guaranteed.append(envelope)
    }

    func confirmDelivery(of envelope: SyncEnvelope) {
        onDelivered?(envelope.id)
    }
}
