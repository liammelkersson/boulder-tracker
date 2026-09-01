import Testing
import Foundation
import SwiftData
@testable import BoulderTracker

/// Drives a real watch-side outbox into the real phone coordinator (and back)
/// through fakes, so the inbox↔outbox seam is exercised end to end.
@MainActor
struct PhoneWatchSyncIntegrationTests {
    private func temporaryQueue() -> PendingEventQueue {
        PendingEventQueue(fileURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("integration-\(UUID().uuidString).json"))
    }

    private func temporaryLiveSessionURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("integration-live-\(UUID().uuidString).json")
    }

    @Test func watchLoggedSessionLandsInPhoneStore() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let phoneLink = FakeSyncLink()
        let phone = PhoneSyncCoordinator(
            context: context, link: phoneLink, queue: temporaryQueue()
        )
        phone.start()

        let watchLive = WatchLiveSession(fileURL: temporaryLiveSessionURL())
        let watchLink = FakeSyncLink()
        let watchOutbox = SessionSyncOutbox(queue: temporaryQueue(), link: watchLink)

        let start = watchLive.startEvent(
            gymName: nil, climbType: .bouldering, startTime: Date(timeIntervalSince1970: 100)
        )
        watchLive.apply(start)
        watchOutbox.send(start)
        let attempt = watchLive.attemptEvent(grade: .red, result: .flash, loggedAt: .now)
        watchLive.apply(attempt)
        watchOutbox.send(attempt)
        let end = watchLive.endEvent(endTime: Date(timeIntervalSince1970: 4000))
        watchLive.apply(end)
        watchOutbox.send(end)

        for envelope in watchLink.guaranteed {
            phoneLink.onReceive?(envelope)
        }

        let stored = try context.fetch(FetchDescriptor<Session>())
        #expect(stored.count == 1)
        #expect(stored.first?.isWatchTracked == true)
        #expect(stored.first?.endTime == Date(timeIntervalSince1970: 4000))
        #expect(stored.first?.problems.first?.flashCount == 1)
    }

    @Test func phoneAttemptReachesTheWatchTally() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let phoneLink = FakeSyncLink()
        let phone = PhoneSyncCoordinator(
            context: context, link: phoneLink, queue: temporaryQueue()
        )
        phone.start()
        let session = Session(startTime: .now, gym: nil, partners: [])
        let problem = SessionProblem(name: "", colorGrade: .blue, styles: [])
        session.problems.append(problem)
        context.insert(session)
        try context.save()
        let watchLive = WatchLiveSession(fileURL: temporaryLiveSessionURL())

        phone.announceStart(of: session)
        phone.announceAttempt(on: problem, in: session, result: .send)
        for envelope in phoneLink.guaranteed {
            watchLive.apply(envelope.event)
        }

        #expect(watchLive.snapshot?.sessionSyncID == session.syncID)
        #expect(watchLive.tally.first { $0.grade == .blue }?.count == 1)
    }
}
