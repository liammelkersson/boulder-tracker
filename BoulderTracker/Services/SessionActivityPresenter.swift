import ActivityKit
import Foundation
import OSLog

/// Owns the Live Activity for the running session. A thin wrapper on purpose:
/// the payload is built by `ClimbingSessionState`, which is testable, while
/// ActivityKit itself does not run under the test host.
///
/// Every entry point is a no-op when the user has Live Activities switched
/// off, so no session flow depends on an Activity existing.
@MainActor
@Observable
final class SessionActivityPresenter {
    /// iOS ends Live Activities after roughly eight hours. Marking the content
    /// stale at the same horizon lets a forgotten session fade out instead of
    /// claiming to still be live.
    private static let maximumSessionDuration: TimeInterval = 8 * 60 * 60

    private var activity: Activity<ClimbingSessionAttributes>?
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func start(for session: Session) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled, activity == nil else { return }
        do {
            activity = try Activity.request(
                attributes: ClimbingSessionState.attributes(for: session),
                content: content(for: session)
            )
        } catch {
            Logger.persistence.error("Live Activity request failed: \(error)")
        }
    }

    func refresh(for session: Session) {
        guard let activity else { return }
        let handle = ActivityHandle(activity: activity)
        let updated = content(for: session)
        Task { await handle.activity.update(updated) }
    }

    func end(for session: Session) {
        guard let activity else { return }
        let handle = ActivityHandle(activity: activity)
        let final = content(for: session)
        self.activity = nil
        Task { await handle.activity.end(final, dismissalPolicy: .immediate) }
    }

    private func content(
        for session: Session
    ) -> ActivityContent<ClimbingSessionAttributes.ContentState> {
        ActivityContent(
            state: ClimbingSessionState.contentState(for: session, gradeSystem: gradeSystem),
            staleDate: session.startTime.addingTimeInterval(Self.maximumSessionDuration)
        )
    }

    private var gradeSystem: GradeSystem {
        let stored = defaults.string(forKey: AppPreferences.gradeSystemKey)
        return stored.flatMap(GradeSystem.init(rawValue:)) ?? .default
    }
}

/// ActivityKit's `Activity` is not `Sendable`, yet `update` and `end` are
/// nonisolated `async`. This presenter creates and reads the handle only on the
/// main actor and never mutates it, so the box states that contract for the
/// compiler instead of leaving the call unbuildable.
private struct ActivityHandle: @unchecked Sendable {
    let activity: Activity<ClimbingSessionAttributes>
}
