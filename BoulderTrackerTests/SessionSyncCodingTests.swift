import Testing
import Foundation
@testable import BoulderTracker

struct SessionSyncCodingTests {
    private func roundTrip(_ event: SessionSyncEvent) throws -> SessionSyncEvent {
        let envelope = SyncEnvelope(event: event)
        let payload = try SessionSyncCoding.messagePayload(for: envelope)
        let decoded = try SessionSyncCoding.envelope(from: payload)
        #expect(decoded.id == envelope.id)
        return decoded.event
    }

    @Test func sessionStartedRoundTrips() throws {
        let sessionSyncID = UUID()
        let event = SessionSyncEvent.sessionStarted(SessionStartPayload(
            sessionSyncID: sessionSyncID, startTime: Date(timeIntervalSince1970: 1000),
            gymName: "Klättervigören Jönköping", climbType: .topRope
        ))
        #expect(try roundTrip(event) == event)
    }

    @Test func attemptLoggedRoundTrips() throws {
        let event = SessionSyncEvent.attemptLogged(AttemptLogPayload(
            sessionSyncID: UUID(), problemSyncID: UUID(), colorGrade: .black,
            result: .flash, loggedAt: Date(timeIntervalSince1970: 2000)
        ))
        #expect(try roundTrip(event) == event)
    }

    @Test func workoutRecordedRoundTrips() throws {
        let event = SessionSyncEvent.workoutRecorded(WorkoutSummaryPayload(
            sessionSyncID: UUID(), workoutID: UUID(),
            avgHeartRate: 132.5, maxHeartRate: 171, activeCalories: 480
        ))
        #expect(try roundTrip(event) == event)
    }

    @Test func snapshotWithProblemsRoundTrips() throws {
        let event = SessionSyncEvent.sessionSnapshot(SessionSnapshotPayload(
            liveSession: LiveSessionSnapshot(
                sessionSyncID: UUID(), startTime: Date(timeIntervalSince1970: 3000),
                gymName: nil, climbType: .bouldering,
                problems: [ProblemCountsSnapshot(
                    problemSyncID: UUID(), colorGrade: .red,
                    flashCount: 1, sendCount: 2, fallCount: 3
                )]
            )
        ))
        #expect(try roundTrip(event) == event)
    }

    @Test func emptySnapshotAndRequestRoundTrip() throws {
        #expect(try roundTrip(.liveSessionRequest) == .liveSessionRequest)
        let empty = SessionSyncEvent.sessionSnapshot(SessionSnapshotPayload(liveSession: nil))
        #expect(try roundTrip(empty) == empty)
    }

    @Test func phoneCatalogRoundTrips() throws {
        let event = SessionSyncEvent.phoneCatalog(PhoneCatalogPayload(
            gyms: [GymSnapshot(name: "Klättervigören Jönköping", isDefault: true)],
            healthKitSyncEnabled: false,
            gradeSystem: .vScale
        ))
        #expect(try roundTrip(event) == event)
    }

    @Test func decodingRejectsPayloadWithoutEnvelope() {
        #expect(throws: SyncCodingFailure.self) {
            try SessionSyncCoding.envelope(from: ["wrong": 1])
        }
    }
}
