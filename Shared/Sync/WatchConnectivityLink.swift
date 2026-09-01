import Foundation
import OSLog
import WatchConnectivity

/// Wraps `WCSession`. Every envelope goes out on both channels: `sendMessage` for
/// the live mirror when the peer is awake, `transferUserInfo` for guaranteed FIFO
/// delivery that survives termination and out-of-range periods.
@MainActor
final class WatchConnectivityLink: NSObject, SyncLinking {
    var onDelivered: ((UUID) -> Void)?
    var onReceive: ((SyncEnvelope) -> Void)?

    private let session = WCSession.default
    private var envelopeIDsByTransfer: [ObjectIdentifier: UUID] = [:]

    var isPeerReachable: Bool {
        WCSession.isSupported() && session.isReachable
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
    }

    func sendImmediately(_ envelope: SyncEnvelope) {
        guard let payload = encodedPayload(for: envelope) else { return }
        session.sendMessage(payload, replyHandler: nil) { _ in
            // Guaranteed channel still carries this envelope; nothing to recover.
        }
    }

    func transferGuaranteed(_ envelope: SyncEnvelope) {
        guard let payload = encodedPayload(for: envelope) else { return }
        let transfer = session.transferUserInfo(payload)
        envelopeIDsByTransfer[ObjectIdentifier(transfer)] = envelope.id
    }

    private func encodedPayload(for envelope: SyncEnvelope) -> [String: Any]? {
        do {
            return try SessionSyncCoding.messagePayload(for: envelope)
        } catch {
            Logger.sync.error("Dropping envelope \(envelope.id): encoding failed: \(error)")
            return nil
        }
    }

    fileprivate func receive(_ envelope: SyncEnvelope) {
        onReceive?(envelope)
    }

    fileprivate func completeTransfer(key: ObjectIdentifier, succeeded: Bool) {
        guard succeeded, let envelopeID = envelopeIDsByTransfer.removeValue(forKey: key) else {
            return
        }
        onDelivered?(envelopeID)
    }
}

extension WatchConnectivityLink: @preconcurrency WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession, activationDidCompleteWith state: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            Logger.sync.error("WCSession activation failed: \(error)")
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        deliverToMainActor(userInfo)
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        deliverToMainActor(message)
    }

    nonisolated func session(
        _ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer,
        error: Error?
    ) {
        // `WCSessionUserInfoTransfer` is not Sendable, so only its identity crosses over.
        let key = ObjectIdentifier(userInfoTransfer)
        let succeeded = error == nil
        Task { @MainActor in self.completeTransfer(key: key, succeeded: succeeded) }
    }

    /// Decodes on the calling thread so only the Sendable envelope crosses actors.
    private nonisolated func deliverToMainActor(_ payload: [String: Any]) {
        do {
            let envelope = try SessionSyncCoding.envelope(from: payload)
            Task { @MainActor in self.receive(envelope) }
        } catch {
            // The sender already got delivery confirmation, so this payload is
            // lost for good — the log is the only trace.
            Logger.sync.error("Dropping undecodable inbound payload: \(error)")
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
