import ActivityKit
import SwiftUI
import WidgetKit

/// Lock Screen and Dynamic Island presentation of a running session.
struct ClimbingSessionActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ClimbingSessionAttributes.self) { context in
            ClimbingSessionLockScreenView(
                attributes: context.attributes, state: context.state
            )
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    SessionElapsedTime(startTime: context.state.startTime, size: 20)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    SendCountLabel(sendCount: context.state.sendCount)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        GradeTallyRow(
                            tally: context.state.tally, gradeSystem: context.state.gradeSystem
                        )
                        QuickSendButtons(
                            grades: context.state.quickGrades,
                            gradeSystem: context.state.gradeSystem
                        )
                    }
                }
            } compactLeading: {
                Image(systemName: "figure.climbing")
            } compactTrailing: {
                SessionElapsedTime(startTime: context.state.startTime, size: 13)
            } minimal: {
                SessionElapsedTime(startTime: context.state.startTime, size: 12)
            }
        }
    }
}

private struct ClimbingSessionLockScreenView: View {
    let attributes: ClimbingSessionAttributes
    let state: ClimbingSessionAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    SessionElapsedTime(startTime: state.startTime, size: 30)
                    Text(attributes.gymName ?? "Session live")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                SendCountLabel(sendCount: state.sendCount)
            }
            GradeTallyRow(tally: state.tally, gradeSystem: state.gradeSystem)
            QuickSendButtons(grades: state.quickGrades, gradeSystem: state.gradeSystem)
        }
        .padding()
        .activityBackgroundTint(.black.opacity(0.55))
    }
}

/// Ticks on its own, so the Activity is only updated when a log lands.
private struct SessionElapsedTime: View {
    let startTime: Date
    let size: CGFloat

    var body: some View {
        Text(timerInterval: startTime...Date.distantFuture, countsDown: false)
            .font(.system(size: size, weight: .bold))
            .monospacedDigit()
    }
}

private struct SendCountLabel: View {
    let sendCount: Int

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text("\(sendCount)")
                .font(.system(size: 22, weight: .bold))
            Text(sendCount == 1 ? "send" : "sends")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private struct GradeTallyRow: View {
    let tally: [GradeTally]
    let gradeSystem: GradeSystem

    var body: some View {
        HStack(spacing: 10) {
            ForEach(tally, id: \.grade) { entry in
                HStack(spacing: 4) {
                    Circle()
                        .fill(entry.grade.displayColor)
                        .frame(width: 8, height: 8)
                    Text("\(entry.grade.shortLabel(in: gradeSystem)) \(entry.count)")
                        .font(.caption)
                }
            }
        }
    }
}

private struct QuickSendButtons: View {
    let grades: [ColorGrade]
    let gradeSystem: GradeSystem

    var body: some View {
        HStack(spacing: 8) {
            ForEach(grades, id: \.self) { grade in
                Button(intent: LogSendIntent(grade: grade)) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(grade.displayColor)
                            .frame(width: 8, height: 8)
                        Text(grade.shortLabel(in: gradeSystem))
                            .font(.caption.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}
