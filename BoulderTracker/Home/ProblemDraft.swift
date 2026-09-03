import Foundation

/// Problem details gathered by a form before any `SessionProblem` exists. A
/// past session has no stored row to append to until the user saves it, so the
/// form collects drafts and materializes them at the end.
struct ProblemDraft: Identifiable {
    let id = UUID()
    var name = ""
    var colorGrade: ColorGrade = .green
    var styles: Set<RouteStyle> = []
    var notes = ""
    var isProject = false
    var photoData: Data?

    /// Builds the stored problem. A photo that fails to write is dropped
    /// rather than losing the whole entry — the attempt log matters more.
    func makeProblem(savePhoto: (Data) throws -> String) -> SessionProblem {
        let problem = SessionProblem(
            name: name, colorGrade: colorGrade, styles: Array(styles)
        )
        if !notes.isEmpty { problem.notes = notes }
        if let photoData {
            problem.photoFilename = try? savePhoto(photoData)
        }
        return problem
    }
}
