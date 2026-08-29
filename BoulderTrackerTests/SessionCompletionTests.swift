import Testing
import Foundation
@testable import BoulderTracker

@MainActor
struct SessionCompletionTests {
    @Test func finishSetsEndTimeAndSavesWorkout() async {
        let writer = FakeWorkoutWriter()
        let completion = SessionCompletion(workoutWriter: writer)
        let session = Session(startTime: .now.addingTimeInterval(-3600), gym: nil, partners: [])

        let outcome = await completion.finish(
            session, endTime: .now, allSessions: [session], unlockedIDs: []
        )

        #expect(session.endTime != nil)
        #expect(session.healthKitWorkoutID == writer.fixedWorkoutID)
        #expect(outcome.workoutSave == .saved)
        #expect(outcome.newAchievements.contains { $0.id == "first-session" })
    }

    @Test func workoutFailureDoesNotBlockCompletion() async {
        let completion = SessionCompletion(workoutWriter: ThrowingWorkoutWriter())
        let session = Session(startTime: .now.addingTimeInterval(-3600), gym: nil, partners: [])

        let outcome = await completion.finish(
            session, endTime: .now, allSessions: [session], unlockedIDs: []
        )

        #expect(session.endTime != nil)
        #expect(outcome.workoutSave == .failed)
        #expect(session.healthKitWorkoutID == nil)
    }

    @Test func missingWriterSkipsHealthKitEntirely() async {
        let completion = SessionCompletion(workoutWriter: nil)
        let session = Session(startTime: .now.addingTimeInterval(-3600), gym: nil, partners: [])

        let outcome = await completion.finish(
            session, endTime: .now, allSessions: [session], unlockedIDs: []
        )

        #expect(session.endTime != nil)
        #expect(outcome.workoutSave == .syncDisabled)
        #expect(session.healthKitWorkoutID == nil)
    }

    @Test func watchTrackedSessionSkipsPhoneWorkoutWrite() async {
        let writer = FakeWorkoutWriter()
        let completion = SessionCompletion(workoutWriter: writer)
        let session = Session(startTime: .now.addingTimeInterval(-3600), gym: nil, partners: [])
        session.isWatchTracked = true

        let outcome = await completion.finish(
            session, endTime: .now, allSessions: [session], unlockedIDs: []
        )

        #expect(session.endTime != nil)
        #expect(outcome.workoutSave == .recordedByWatch)
        #expect(writer.savedIntervals.isEmpty)
    }

    @Test func watchTrackedSessionKeepsWorkoutIDFromTheWatch() async {
        let watchWorkoutID = UUID()
        let completion = SessionCompletion(workoutWriter: FakeWorkoutWriter())
        let session = Session(startTime: .now.addingTimeInterval(-3600), gym: nil, partners: [])
        session.isWatchTracked = true
        session.healthKitWorkoutID = watchWorkoutID

        _ = await completion.finish(
            session, endTime: .now, allSessions: [session], unlockedIDs: []
        )

        #expect(session.healthKitWorkoutID == watchWorkoutID)
    }
}

private final class ThrowingWorkoutWriter: WorkoutWriting, @unchecked Sendable {
    struct Refused: Error {}
    func requestAuthorization() async throws { throw Refused() }
    func saveClimbingWorkout(start: Date, end: Date) async throws -> UUID { throw Refused() }
    func deleteClimbingWorkout(id: UUID) async throws { throw Refused() }
}
