import SwiftUI
import SwiftData

/// Fast logging for unnamed volume problems: tap a grade, pick the result.
/// Logs accumulate on one unnamed problem per grade in the session.
struct QuickLogRow: View {
    @Environment(\.palette) private var palette
    @Environment(\.gradeSystem) private var gradeSystem
    @Environment(\.modelContext) private var modelContext
    @Environment(PhoneSyncCoordinator.self) private var syncCoordinator
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
                    .font(.system(size: 13, weight: .medium))
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
        let problem = session.problems.first { $0.name.isEmpty && $0.colorGrade == grade }
            ?? createQuickLogProblem(grade: grade)
        problem.recordResult(result)
        try? modelContext.save()
        syncCoordinator.announceAttempt(on: problem, in: session, result: result)
    }

    private func createQuickLogProblem(grade: ColorGrade) -> SessionProblem {
        let problem = SessionProblem(name: "", colorGrade: grade, styles: [])
        session.problems.append(problem)
        return problem
    }
}
