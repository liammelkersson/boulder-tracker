import SwiftUI

struct WatchSummaryView: View {
    let duration: TimeInterval
    let metrics: WorkoutMetrics?
    let onDone: () -> Void

    var body: some View {
        List {
            LabeledContent("Duration", value: durationLabel)
            if let avgHeartRate = metrics?.avgHeartRate {
                LabeledContent("Avg BPM", value: "\(Int(avgHeartRate.rounded()))")
            }
            if let calories = metrics?.activeCalories {
                LabeledContent("Calories", value: "\(Int(calories.rounded()))")
            }
            Button("Done", action: onDone)
        }
        .navigationTitle("Done")
    }

    private var durationLabel: String {
        let minutes = Int(duration) / 60
        return "\(minutes) min"
    }
}
