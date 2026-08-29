import Testing
import Foundation
@testable import BoulderTracker

@MainActor
struct LiveSessionSnapshotReaderTests {
    @Test func noSessionYieldsNoSnapshot() {
        #expect(LiveSessionSnapshotReader.snapshot(of: nil) == nil)
    }

    @Test func finishedSessionYieldsNoSnapshot() {
        let session = Session(startTime: .now, gym: nil, partners: [])
        session.endTime = .now

        #expect(LiveSessionSnapshotReader.snapshot(of: session) == nil)
    }

    @Test func liveSessionCarriesGymClimbTypeAndCounts() {
        let gym = Gym(name: "Klättervigören Jönköping", isDefault: true)
        let session = Session(
            startTime: Date(timeIntervalSince1970: 900), gym: gym,
            partners: [], climbType: .lead
        )
        let problem = SessionProblem(
            name: "", colorGrade: .black, styles: [],
            flashCount: 1, sendCount: 2, fallCount: 3
        )
        session.problems.append(problem)

        let snapshot = LiveSessionSnapshotReader.snapshot(of: session)

        #expect(snapshot?.sessionSyncID == session.syncID)
        #expect(snapshot?.startTime == Date(timeIntervalSince1970: 900))
        #expect(snapshot?.gymName == "Klättervigören Jönköping")
        #expect(snapshot?.climbType == .lead)
        #expect(snapshot?.problems.count == 1)
        #expect(snapshot?.problems.first?.colorGrade == .black)
        #expect(snapshot?.problems.first?.flashCount == 1)
        #expect(snapshot?.problems.first?.sendCount == 2)
        #expect(snapshot?.problems.first?.fallCount == 3)
    }

    @Test func problemsWithoutSyncIDsAreOmitted() {
        let session = Session(startTime: .now, gym: nil, partners: [])
        let problem = SessionProblem(name: "", colorGrade: .green, styles: [], sendCount: 1)
        problem.syncID = nil
        session.problems.append(problem)

        #expect(LiveSessionSnapshotReader.snapshot(of: session)?.problems.isEmpty == true)
    }
}
