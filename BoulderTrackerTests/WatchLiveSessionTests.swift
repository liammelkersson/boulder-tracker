import Testing
import Foundation
@testable import BoulderTracker

@MainActor
struct WatchLiveSessionTests {
    private func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("watch-live-\(UUID().uuidString).json")
    }

    private func started(_ live: WatchLiveSession, gymName: String? = "Klättervigören Jönköping") {
        live.apply(live.startEvent(
            gymName: gymName, climbType: .bouldering,
            startTime: Date(timeIntervalSince1970: 100)
        ))
    }

    @Test func newSessionHasNothingLive() {
        #expect(WatchLiveSession(fileURL: temporaryFileURL()).snapshot == nil)
    }

    @Test func startingRecordsGymAndClimbType() {
        let live = WatchLiveSession(fileURL: temporaryFileURL())

        started(live)

        #expect(live.snapshot?.gymName == "Klättervigören Jönköping")
        #expect(live.snapshot?.climbType == .bouldering)
        #expect(live.snapshot?.startTime == Date(timeIntervalSince1970: 100))
        #expect(live.snapshot?.problems.isEmpty == true)
    }

    @Test func loggingAccumulatesOneProblemPerGrade() {
        let live = WatchLiveSession(fileURL: temporaryFileURL())
        started(live)

        live.apply(live.attemptEvent(grade: .red, result: .fall, loggedAt: .now))
        live.apply(live.attemptEvent(grade: .red, result: .send, loggedAt: .now))
        live.apply(live.attemptEvent(grade: .blue, result: .flash, loggedAt: .now))

        #expect(live.snapshot?.problems.count == 2)
        let red = live.snapshot?.problems.first { $0.colorGrade == .red }
        #expect(red?.fallCount == 1)
        #expect(red?.sendCount == 1)
    }

    @Test func tallyCountsEveryLogPerGrade() {
        let live = WatchLiveSession(fileURL: temporaryFileURL())
        started(live)
        live.apply(live.attemptEvent(grade: .red, result: .fall, loggedAt: .now))
        live.apply(live.attemptEvent(grade: .red, result: .send, loggedAt: .now))

        #expect(live.tally.first { $0.grade == .red }?.count == 2)
        #expect(live.tally.contains { $0.grade == .blue } == false)
    }

    @Test func endingClearsTheLiveSession() {
        let live = WatchLiveSession(fileURL: temporaryFileURL())
        started(live)

        live.apply(live.endEvent(endTime: .now))

        #expect(live.snapshot == nil)
    }

    @Test func remoteAttemptFromThePhoneIsMerged() {
        let live = WatchLiveSession(fileURL: temporaryFileURL())
        started(live)
        guard let sessionSyncID = live.snapshot?.sessionSyncID else {
            Issue.record("no live session")
            return
        }

        live.apply(.attemptLogged(AttemptLogPayload(
            sessionSyncID: sessionSyncID, problemSyncID: UUID(), colorGrade: .white,
            result: .send, loggedAt: .now
        )))

        #expect(live.tally.first { $0.grade == .white }?.count == 1)
    }

    @Test func eventsForAnotherSessionAreIgnored() {
        let live = WatchLiveSession(fileURL: temporaryFileURL())
        started(live)

        live.apply(.attemptLogged(AttemptLogPayload(
            sessionSyncID: UUID(), problemSyncID: UUID(), colorGrade: .white,
            result: .send, loggedAt: .now
        )))

        #expect(live.snapshot?.problems.isEmpty == true)
    }

    @Test func snapshotAdoptionFillsAnEmptyWatch() {
        let live = WatchLiveSession(fileURL: temporaryFileURL())
        let adopted = LiveSessionSnapshot(
            sessionSyncID: UUID(), startTime: Date(timeIntervalSince1970: 700),
            gymName: "Elsewhere", climbType: .lead,
            problems: [ProblemCountsSnapshot(
                problemSyncID: UUID(), colorGrade: .green,
                flashCount: 2, sendCount: 0, fallCount: 0
            )]
        )

        live.apply(.sessionSnapshot(SessionSnapshotPayload(liveSession: adopted)))

        #expect(live.snapshot == adopted)
    }

    @Test func snapshotNeverOverwritesAnActiveWatchSession() {
        let live = WatchLiveSession(fileURL: temporaryFileURL())
        started(live)
        let ownID = live.snapshot?.sessionSyncID

        live.apply(.sessionSnapshot(SessionSnapshotPayload(liveSession: LiveSessionSnapshot(
            sessionSyncID: UUID(), startTime: .now, gymName: "Elsewhere",
            climbType: .lead, problems: []
        ))))

        #expect(live.snapshot?.sessionSyncID == ownID)
    }

    @Test func redeliveredSessionStartKeepsLoggedProblems() {
        let live = WatchLiveSession(fileURL: temporaryFileURL())
        started(live)
        guard let current = live.snapshot else {
            Issue.record("no live session")
            return
        }
        live.apply(live.attemptEvent(grade: .red, result: .send, loggedAt: .now))

        live.apply(.sessionStarted(SessionStartPayload(
            sessionSyncID: current.sessionSyncID, startTime: current.startTime,
            gymName: current.gymName, climbType: current.climbType
        )))

        #expect(live.snapshot?.problems.count == 1)
    }

    @Test func olderRemoteSessionStartIsIgnored() {
        let live = WatchLiveSession(fileURL: temporaryFileURL())
        started(live)
        let ownID = live.snapshot?.sessionSyncID

        live.apply(.sessionStarted(SessionStartPayload(
            sessionSyncID: UUID(), startTime: Date(timeIntervalSince1970: 50),
            gymName: "Elsewhere", climbType: .lead
        )))

        #expect(live.snapshot?.sessionSyncID == ownID)
    }

    @Test func newerRemoteSessionStartReplacesTheCurrentOne() {
        let live = WatchLiveSession(fileURL: temporaryFileURL())
        started(live)
        let newerID = UUID()

        live.apply(.sessionStarted(SessionStartPayload(
            sessionSyncID: newerID, startTime: Date(timeIntervalSince1970: 900),
            gymName: "Elsewhere", climbType: .lead
        )))

        #expect(live.snapshot?.sessionSyncID == newerID)
    }

    @Test func liveSessionSurvivesRelaunch() {
        let fileURL = temporaryFileURL()
        let live = WatchLiveSession(fileURL: fileURL)
        started(live)
        live.apply(live.attemptEvent(grade: .black, result: .flash, loggedAt: .now))

        let reopened = WatchLiveSession(fileURL: fileURL)

        #expect(reopened.snapshot?.sessionSyncID == live.snapshot?.sessionSyncID)
        #expect(reopened.tally.first { $0.grade == .black }?.count == 1)
    }
}
