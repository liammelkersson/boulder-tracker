import Foundation

/// Wraps an event with the identity used for delivery de-duplication. The same
/// envelope is sent over both WatchConnectivity channels, so peers see duplicates.
struct SyncEnvelope: Codable, Sendable, Equatable {
    let id: UUID
    let sentAt: Date
    let event: SessionSyncEvent

    init(id: UUID = UUID(), sentAt: Date = .now, event: SessionSyncEvent) {
        self.id = id
        self.sentAt = sentAt
        self.event = event
    }
}
