import SwiftUI
import SwiftData

/// Adds a problem to a session that already exists — live or already ended.
struct QuickAddProblemSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let session: Session

    private let photoStore = PhotoStore.makeDefault()

    var body: some View {
        ProblemFormSheet(
            title: "New Problem", actionTitle: "Add Problem", onSubmit: addProblem
        )
    }

    private func addProblem(_ draft: ProblemDraft) {
        let problem = draft.makeProblem(savePhoto: photoStore.savePhoto)
        session.problems.append(problem)
        if draft.isProject {
            ProjectLinking.linkProject(to: problem, in: modelContext)
        }
        modelContext.saveReportingFailure(operation: "problem add")
        dismiss()
    }
}
