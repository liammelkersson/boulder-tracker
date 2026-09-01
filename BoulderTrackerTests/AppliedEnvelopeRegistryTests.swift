import Testing
import Foundation
@testable import BoulderTracker

@MainActor
struct AppliedEnvelopeRegistryTests {
    private func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("applied-envelopes-\(UUID().uuidString).json")
    }

    @Test func unseenIDIsNotContained() {
        let registry = AppliedEnvelopeRegistry(fileURL: temporaryFileURL())
        #expect(registry.contains(UUID()) == false)
    }

    @Test func recordedIDIsContained() {
        let registry = AppliedEnvelopeRegistry(fileURL: temporaryFileURL())
        let id = UUID()

        registry.record(id)

        #expect(registry.contains(id))
    }

    @Test func recordedIDsSurviveRelaunch() {
        let fileURL = temporaryFileURL()
        let registry = AppliedEnvelopeRegistry(fileURL: fileURL)
        let id = UUID()
        registry.record(id)

        let reopened = AppliedEnvelopeRegistry(fileURL: fileURL)

        #expect(reopened.contains(id))
    }

    @Test func oldestIDsAreEvictedAtCapacity() {
        let registry = AppliedEnvelopeRegistry(fileURL: temporaryFileURL())
        let first = UUID()
        registry.record(first)

        for _ in 0..<AppliedEnvelopeRegistry.capacity {
            registry.record(UUID())
        }

        #expect(registry.contains(first) == false)
    }
}
