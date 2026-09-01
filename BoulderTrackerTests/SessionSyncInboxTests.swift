import Testing
import Foundation
import SwiftData
@testable import BoulderTracker

@MainActor
struct SessionSyncInboxTests {
    private let sessionSyncID = UUID()
    private let problemSyncID = UUID()

    private func startEvent(gymName: String? = nil) -> SessionSyncEvent {
        .sessionStarted(SessionStartPayload(
            sessionSyncID: sessionSyncID, startTime: Date(timeIntervalSince1970: 1000),
            gymName: gymName, climbType: .bouldering
        ))
    }

    private func attemptEvent(_ result: AttemptResult) -> SessionSyncEvent {
        .attemptLogged(AttemptLogPayload(
            sessionSyncID: sessionSyncID, problemSyncID: problemSyncID,
            colorGrade: .red, result: result, loggedAt: Date(timeIntervalSince1970: 1100)
        ))
    }

    private func sessions(in context: ModelContext) throws -> [Session] {
        try context.fetch(FetchDescriptor<Session>())
    }

    @Test func sessionStartedCreatesWatchTrackedSession() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let inbox = SessionSyncInbox(context: context)

        inbox.apply(SyncEnvelope(event: startEvent()))

        let stored = try sessions(in: context)
        #expect(stored.count == 1)
        #expect(stored.first?.syncID == sessionSyncID)
        #expect(stored.first?.isWatchTracked == true)
        #expect(stored.first?.isLive == true)
    }

    @Test func sessionStartedLinksExistingGymByName() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        context.insert(Gym(name: "Klättervigören Jönköping", isDefault: true))
        try context.save()
        let inbox = SessionSyncInbox(context: context)

        inbox.apply(SyncEnvelope(event: startEvent(gymName: "Klättervigören Jönköping")))

        #expect(try sessions(in: context).first?.gym?.name == "Klättervigören Jönköping")
    }

    @Test func replayingSessionStartedDoesNotDuplicate() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let inbox = SessionSyncInbox(context: context)
        let envelope = SyncEnvelope(event: startEvent())

        inbox.apply(envelope)
        inbox.apply(envelope)

        #expect(try sessions(in: context).count == 1)
    }

    @Test func attemptCreatesProblemFromCarriedGrade() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let inbox = SessionSyncInbox(context: context)
        inbox.apply(SyncEnvelope(event: startEvent()))

        inbox.apply(SyncEnvelope(event: attemptEvent(.flash)))

        let problems = try sessions(in: context).first?.problems ?? []
        #expect(problems.count == 1)
        #expect(problems.first?.colorGrade == .red)
        #expect(problems.first?.flashCount == 1)
        #expect(problems.first?.syncID == problemSyncID)
    }

    @Test func replayingAttemptCountsOnce() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let inbox = SessionSyncInbox(context: context)
        inbox.apply(SyncEnvelope(event: startEvent()))
        let envelope = SyncEnvelope(event: attemptEvent(.send))

        inbox.apply(envelope)
        inbox.apply(envelope)
        inbox.apply(envelope)

        #expect(try sessions(in: context).first?.problems.first?.sendCount == 1)
    }

    @Test func distinctAttemptsAccumulateOnOneProblem() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let inbox = SessionSyncInbox(context: context)
        inbox.apply(SyncEnvelope(event: startEvent()))

        inbox.apply(SyncEnvelope(event: attemptEvent(.fall)))
        inbox.apply(SyncEnvelope(event: attemptEvent(.fall)))
        inbox.apply(SyncEnvelope(event: attemptEvent(.send)))

        let problems = try sessions(in: context).first?.problems ?? []
        #expect(problems.count == 1)
        #expect(problems.first?.fallCount == 2)
        #expect(problems.first?.sendCount == 1)
    }

    @Test func attemptArrivingBeforeSessionReplaysOnceSessionArrives() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let inbox = SessionSyncInbox(context: context)

        inbox.apply(SyncEnvelope(event: attemptEvent(.flash)))
        #expect(try sessions(in: context).isEmpty)

        inbox.apply(SyncEnvelope(event: startEvent()))

        #expect(try sessions(in: context).first?.problems.first?.flashCount == 1)
    }

    @Test func sessionEndedSetsEndTime() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let inbox = SessionSyncInbox(context: context)
        inbox.apply(SyncEnvelope(event: startEvent()))
        let endTime = Date(timeIntervalSince1970: 5000)

        inbox.apply(SyncEnvelope(event: .sessionEnded(
            SessionEndPayload(sessionSyncID: sessionSyncID, endTime: endTime)
        )))

        #expect(try sessions(in: context).first?.endTime == endTime)
    }

    @Test func workoutRecordedStoresIDAndHeartRate() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let inbox = SessionSyncInbox(context: context)
        inbox.apply(SyncEnvelope(event: startEvent()))
        let workoutID = UUID()

        inbox.apply(SyncEnvelope(event: .workoutRecorded(WorkoutSummaryPayload(
            sessionSyncID: sessionSyncID, workoutID: workoutID,
            avgHeartRate: 141, maxHeartRate: 178, activeCalories: 505
        ))))

        let stored = try sessions(in: context).first
        #expect(stored?.healthKitWorkoutID == workoutID)
        #expect(stored?.avgHeartRate == 141)
        #expect(stored?.maxHeartRate == 178)
        #expect(stored?.activeCalories == 505)
    }

    @Test func adoptingNewerLiveSessionClosesTheExistingOne() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let phoneSession = Session(
            startTime: Date(timeIntervalSince1970: 500), gym: nil, partners: []
        )
        context.insert(phoneSession)
        try context.save()
        let inbox = SessionSyncInbox(context: context)

        inbox.apply(SyncEnvelope(event: startEvent()))

        let stored = try sessions(in: context)
        #expect(stored.filter(\.isLive).count == 1)
        #expect(stored.first { $0.isLive }?.syncID == sessionSyncID)
        #expect(phoneSession.endTime == Date(timeIntervalSince1970: 1000))
    }

    @Test func adoptingOlderLiveSessionClosesItInsteadOfTheCurrentOne() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let phoneSession = Session(
            startTime: Date(timeIntervalSince1970: 5000), gym: nil, partners: []
        )
        context.insert(phoneSession)
        try context.save()
        let inbox = SessionSyncInbox(context: context)

        inbox.apply(SyncEnvelope(event: startEvent()))

        let stored = try sessions(in: context)
        #expect(stored.filter(\.isLive).count == 1)
        #expect(phoneSession.isLive)
        let adopted = stored.first { $0.syncID == sessionSyncID }
        #expect(adopted?.endTime == Date(timeIntervalSince1970: 5000))
    }

    @Test func unknownSessionEndIsIgnored() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let inbox = SessionSyncInbox(context: context)

        inbox.apply(SyncEnvelope(event: .sessionEnded(
            SessionEndPayload(sessionSyncID: UUID(), endTime: .now)
        )))

        #expect(try sessions(in: context).isEmpty)
    }
}
