import Foundation

enum SyncCodingFailure: Error {
    case payloadMissingEnvelope
}

/// Bridges envelopes to the `[String: Any]` dictionaries WatchConnectivity accepts,
/// keeping the whole envelope in one `Data` value so plist type limits never apply.
enum SessionSyncCoding {
    static let envelopeKey = "envelope"

    static func messagePayload(for envelope: SyncEnvelope) throws -> [String: Any] {
        [envelopeKey: try JSONEncoder().encode(envelope)]
    }

    static func envelope(from payload: [String: Any]) throws -> SyncEnvelope {
        guard let data = payload[envelopeKey] as? Data else {
            throw SyncCodingFailure.payloadMissingEnvelope
        }
        return try JSONDecoder().decode(SyncEnvelope.self, from: data)
    }
}
