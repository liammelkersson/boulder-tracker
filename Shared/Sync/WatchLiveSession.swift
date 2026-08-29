import Foundation
import Observation

/// The watch's view of the session in progress, persisted so a crash or relaunch
/// mid-session loses nothing. Quick logs collapse onto one problem per grade,
/// matching the phone's `QuickLogRow` behaviour.
@MainActor
@Observable
final class WatchLiveSession {
    private(set) var snapshot: LiveSessionSnapshot?
    @ObservationIgnored private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
        self.snapshot = Self.storedSnapshot(at: fileURL)
    }

    var tally: [(grade: ColorGrade, count: Int)] {
        let problems = snapshot?.problems ?? []
        return ColorGrade.displayOrder.compactMap { grade in
            let count = problems
                .filter { $0.colorGrade == grade }
                .reduce(0) { $0 + $1.flashCount + $1.sendCount + $1.fallCount }
            return count > 0 ? (grade, count) : nil
        }
    }

    func startEvent(
        gymName: String?, climbType: ClimbType, startTime: Date
    ) -> SessionSyncEvent {
        .sessionStarted(SessionStartPayload(
            sessionSyncID: UUID(), startTime: startTime,
            gymName: gymName, climbType: climbType
        ))
    }

    func attemptEvent(
        grade: ColorGrade, result: AttemptResult, loggedAt: Date
    ) -> SessionSyncEvent {
        .attemptLogged(AttemptLogPayload(
            sessionSyncID: snapshot?.sessionSyncID ?? UUID(),
            problemSyncID: problemSyncID(for: grade),
            colorGrade: grade, result: result, loggedAt: loggedAt
        ))
    }

    func endEvent(endTime: Date) -> SessionSyncEvent {
        .sessionEnded(SessionEndPayload(
            sessionSyncID: snapshot?.sessionSyncID ?? UUID(), endTime: endTime
        ))
    }

    func apply(_ event: SessionSyncEvent) {
        switch event {
        case .sessionStarted(let payload):
            snapshot = LiveSessionSnapshot(
                sessionSyncID: payload.sessionSyncID, startTime: payload.startTime,
                gymName: payload.gymName, climbType: payload.climbType, problems: []
            )
        case .attemptLogged(let payload):
            countAttempt(payload)
        case .sessionEnded(let payload):
            guard payload.sessionSyncID == snapshot?.sessionSyncID else { return }
            snapshot = nil
        case .sessionSnapshot(let payload):
            guard snapshot == nil else { return }
            snapshot = payload.liveSession
        case .workoutRecorded, .liveSessionRequest, .phoneCatalog:
            // Not part of live session state.
            return
        }
        persist()
    }

    private func countAttempt(_ payload: AttemptLogPayload) {
        guard let current = snapshot, payload.sessionSyncID == current.sessionSyncID else {
            return
        }
        var problems = current.problems
        let index = problems.firstIndex { $0.colorGrade == payload.colorGrade }
            ?? appendProblem(payload, to: &problems)
        problems[index] = incremented(problems[index], by: payload.result)
        snapshot = LiveSessionSnapshot(
            sessionSyncID: current.sessionSyncID, startTime: current.startTime,
            gymName: current.gymName, climbType: current.climbType, problems: problems
        )
    }

    private func appendProblem(
        _ payload: AttemptLogPayload, to problems: inout [ProblemCountsSnapshot]
    ) -> Int {
        problems.append(ProblemCountsSnapshot(
            problemSyncID: payload.problemSyncID, colorGrade: payload.colorGrade,
            flashCount: 0, sendCount: 0, fallCount: 0
        ))
        return problems.count - 1
    }

    private func incremented(
        _ counts: ProblemCountsSnapshot, by result: AttemptResult
    ) -> ProblemCountsSnapshot {
        ProblemCountsSnapshot(
            problemSyncID: counts.problemSyncID,
            colorGrade: counts.colorGrade,
            flashCount: counts.flashCount + (result == .flash ? 1 : 0),
            sendCount: counts.sendCount + (result == .send ? 1 : 0),
            fallCount: counts.fallCount + (result == .fall ? 1 : 0)
        )
    }

    /// One problem per grade, reusing the existing id so repeat logs merge on the phone.
    private func problemSyncID(for grade: ColorGrade) -> UUID {
        snapshot?.problems.first { $0.colorGrade == grade }?.problemSyncID ?? UUID()
    }

    private func persist() {
        guard let snapshot else {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func storedSnapshot(at fileURL: URL) -> LiveSessionSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(LiveSessionSnapshot.self, from: data)
    }
}
