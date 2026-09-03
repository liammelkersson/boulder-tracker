import SwiftUI
import SwiftData

/// Fast logging for unnamed volume problems: tap a grade, pick the result.
/// Logs accumulate on one unnamed problem per grade in the session.
struct QuickLogRow: View {
    @Environment(\.palette) private var palette
    @Environment(\.gradeSystem) private var gradeSystem
    @Environment(\.modelContext) private var modelContext
    @Environment(PhoneSyncCoordinator.self) private var syncCoordinator
    @Environment(SessionActivityPresenter.self) private var activityPresenter
    let session: Session

    @State private var pendingGrade: ColorGrade?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeading(title: "Quick Log")
            FlowLayout(spacing: 8) {
                ForEach(ColorGrade.displayOrder) { grade in
                    gradePill(grade)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .confirmationDialog(
            "Log \(pendingGrade?.shortLabel(in: gradeSystem) ?? "") problem",
            isPresented: pendingGradeBinding,
            titleVisibility: .visible,
            presenting: pendingGrade
        ) { grade in
            ForEach(AttemptResult.allCases) { result in
                Button(result.displayName) { log(grade: grade, result: result) }
            }
        }
    }

    private func gradePill(_ grade: ColorGrade) -> some View {
        Button {
            pendingGrade = grade
        } label: {
            HStack(spacing: 7) {
                GradeDot(grade: grade, size: 11)
                Text("+ \(grade.shortLabel(in: gradeSystem))")
                    .scaledFont(size: 13, weight: .medium)
                    .foregroundStyle(palette.textDim)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(palette.pill)
            .clipShape(.capsule)
        }
        .buttonStyle(.plain)
    }

    private var pendingGradeBinding: Binding<Bool> {
        Binding(
            get: { pendingGrade != nil },
            set: { isPresented in if !isPresented { pendingGrade = nil } }
        )
    }

    private func log(grade: ColorGrade, result: AttemptResult) {
        let problem = QuickLogEntry.problem(for: grade, in: session)
        problem.recordResult(result)
        modelContext.saveReportingFailure(operation: "quick log")
        syncCoordinator.announceAttempt(on: problem, in: session, result: result)
        activityPresenter.refresh(for: session)
    }
}
