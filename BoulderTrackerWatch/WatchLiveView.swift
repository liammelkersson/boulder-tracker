import SwiftUI

struct WatchLiveView: View {
    let snapshot: LiveSessionSnapshot
    let tally: [(grade: ColorGrade, count: Int)]
    let heartRate: Double?
    let gradeSystem: GradeSystem
    let onLog: (ColorGrade, AttemptResult) -> Void
    let onEnd: () -> Void

    @State private var isLogging = false
    @State private var isConfirmingEnd = false

    var body: some View {
        List {
            Section {
                elapsedText
                heartRateText
            }
            if !tally.isEmpty {
                Section("Logged") {
                    ForEach(tally, id: \.grade) { entry in
                        HStack {
                            Text(entry.grade.shortLabel(in: gradeSystem))
                            Spacer()
                            Text("\(entry.count)").monospacedDigit()
                        }
                    }
                }
            }
            Section {
                Button("Log") { isLogging = true }
                Button("End", role: .destructive) { isConfirmingEnd = true }
            }
        }
        .navigationTitle(snapshot.gymName ?? "Session")
        .sheet(isPresented: $isLogging) {
            NavigationStack {
                WatchLogSheet(gradeSystem: gradeSystem) { grade, result in
                    onLog(grade, result)
                    isLogging = false
                }
            }
        }
        .confirmationDialog("End session?", isPresented: $isConfirmingEnd) {
            Button("End", role: .destructive, action: onEnd)
        }
    }

    private var elapsedText: some View {
        TimelineView(.periodic(from: snapshot.startTime, by: 1)) { context in
            Text(elapsedLabel(at: context.date))
                .font(.system(size: 30, weight: .bold))
                .monospacedDigit()
        }
    }

    @ViewBuilder private var heartRateText: some View {
        if let heartRate {
            Label("\(Int(heartRate.rounded())) BPM", systemImage: "heart.fill")
                .foregroundStyle(.red)
        }
    }

    private func elapsedLabel(at now: Date) -> String {
        let elapsed = Int(max(0, now.timeIntervalSince(snapshot.startTime)))
        let hours = elapsed / 3600
        let minutes = (elapsed % 3600) / 60
        let seconds = elapsed % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
