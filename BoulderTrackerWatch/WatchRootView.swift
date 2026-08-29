import SwiftUI

struct WatchRootView: View {
    @State private var coordinator = WatchSyncCoordinator()

    var body: some View {
        NavigationStack {
            content
        }
        .task { coordinator.start() }
    }

    @ViewBuilder private var content: some View {
        if let duration = coordinator.finishedDuration {
            WatchSummaryView(duration: duration, metrics: coordinator.lastMetrics) {
                coordinator.dismissSummary()
            }
        } else if let snapshot = coordinator.liveSession.snapshot {
            WatchLiveView(
                snapshot: snapshot,
                tally: coordinator.liveSession.tally,
                heartRate: coordinator.workout.currentHeartRate,
                onLog: { grade, result in coordinator.log(grade: grade, result: result) },
                onEnd: { coordinator.finishSession() }
            )
        } else {
            WatchStartView(gyms: coordinator.gyms) { gymName, climbType in
                coordinator.beginSession(gymName: gymName, climbType: climbType)
            }
        }
    }
}
