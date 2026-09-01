import Testing
import Foundation
@testable import BoulderTracker

struct PendingEventQueueTests {
    private func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("queue-\(UUID().uuidString).json")
    }

    private func endedEvent() -> SessionSyncEvent {
        .sessionEnded(SessionEndPayload(sessionSyncID: UUID(), endTime: .now))
    }

    @Test func newQueueIsEmpty() {
        #expect(PendingEventQueue(fileURL: temporaryFileURL()).pending.isEmpty)
    }

    @Test func appendedEnvelopesArePending() {
        let queue = PendingEventQueue(fileURL: temporaryFileURL())
        let envelope = SyncEnvelope(event: endedEvent())

        queue.append(envelope)

        #expect(queue.pending.map(\.id) == [envelope.id])
    }

    @Test func removingDeliveredEnvelopeDropsIt() {
        let queue = PendingEventQueue(fileURL: temporaryFileURL())
        let first = SyncEnvelope(event: endedEvent())
        let second = SyncEnvelope(event: endedEvent())
        queue.append(first)
        queue.append(second)

        queue.remove(deliveredID: first.id)

        #expect(queue.pending.map(\.id) == [second.id])
    }

    @Test func pendingEnvelopesSurviveANewInstance() {
        let fileURL = temporaryFileURL()
        let envelope = SyncEnvelope(event: endedEvent())
        PendingEventQueue(fileURL: fileURL).append(envelope)

        let reopened = PendingEventQueue(fileURL: fileURL)

        #expect(reopened.pending.map(\.id) == [envelope.id])
    }

    @Test func removalSurvivesANewInstance() {
        let fileURL = temporaryFileURL()
        let queue = PendingEventQueue(fileURL: fileURL)
        let envelope = SyncEnvelope(event: endedEvent())
        queue.append(envelope)
        queue.remove(deliveredID: envelope.id)

        #expect(PendingEventQueue(fileURL: fileURL).pending.isEmpty)
    }

    @Test func corruptFileYieldsEmptyQueue() throws {
        let fileURL = temporaryFileURL()
        try Data("not json".utf8).write(to: fileURL)

        #expect(PendingEventQueue(fileURL: fileURL).pending.isEmpty)
    }
}

@MainActor
struct PendingEventQueueCapacityTests {
    @Test func queueDropsOldestBeyondCapacity() {
        let queue = PendingEventQueue(fileURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("queue-cap-\(UUID().uuidString).json"))
        let first = SyncEnvelope(event: .liveSessionRequest)
        queue.append(first)

        for _ in 0..<PendingEventQueue.capacity {
            queue.append(SyncEnvelope(event: .liveSessionRequest))
        }

        #expect(queue.pending.count == PendingEventQueue.capacity)
        #expect(queue.pending.contains { $0.id == first.id } == false)
    }
}
