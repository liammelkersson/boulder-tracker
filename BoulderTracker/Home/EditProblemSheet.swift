import SwiftUI
import SwiftData

/// Edits a problem that is already stored — the only way to add styles, a name,
/// or notes to a row after it was logged, quick logs included.
struct EditProblemSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let problem: SessionProblem

    private let photoStore = PhotoStore.makeDefault()

    var body: some View {
        ProblemFormSheet(
            title: "Edit Problem",
            actionTitle: "Save",
            initialDraft: ProblemDraft(problem: problem, loadPhoto: photoStore.loadPhoto),
            onSubmit: saveProblem
        )
    }

    private func saveProblem(_ draft: ProblemDraft) {
        draft.apply(
            to: problem,
            savePhoto: photoStore.savePhoto,
            deletePhoto: photoStore.deletePhoto
        )
        applyProjectMark(draft.isProject)
        modelContext.saveReportingFailure(operation: "problem edit")
        dismiss()
    }

    /// The form's toggle is the user's intent; naming a quick log in the same
    /// edit is what makes the mark possible at all.
    private func applyProjectMark(_ isProject: Bool) {
        switch (isProject, problem.project) {
        case (true, nil):
            ProjectLinking.linkProject(to: problem, in: modelContext)
        case (false, .some):
            ProjectLinking.unlinkProject(from: problem)
        default:
            break
        }
    }
}
