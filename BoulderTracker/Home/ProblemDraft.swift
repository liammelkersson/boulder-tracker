import Foundation

/// Problem details gathered by a form before any `SessionProblem` exists. A
/// past session has no stored row to append to until the user saves it, so the
/// form collects drafts and materializes them at the end. Seeding a draft from
/// a stored problem turns the same form into an editor.
struct ProblemDraft: Identifiable {
    let id = UUID()
    var name = ""
    var colorGrade: ColorGrade = .green
    var styles: Set<RouteStyle> = []
    var skills: Set<MovementSkill> = []
    var notes = ""
    var isProject = false
    var photoData: Data?
    /// The photo already on disk when this draft was seeded, if any. `apply`
    /// compares against it to tell a replaced photo from an untouched one.
    private var storedPhoto: StoredPhoto?

    init() {}

    /// Seeds the form from a stored problem. The photo is loaded eagerly so the
    /// picker can show it and so a save can tell whether it changed.
    init(problem: SessionProblem, loadPhoto: (String) -> Data?) {
        name = problem.name
        colorGrade = problem.colorGrade
        styles = Set(problem.styles)
        skills = Set(problem.skills)
        notes = problem.notes ?? ""
        isProject = problem.project != nil
        if let filename = problem.photoFilename {
            let bytes = loadPhoto(filename)
            storedPhoto = StoredPhoto(filename: filename, bytes: bytes)
            photoData = bytes
        }
    }

    /// Builds the stored problem. A photo that fails to write is dropped
    /// rather than losing the whole entry — the attempt log matters more.
    func makeProblem(savePhoto: (Data) throws -> String) -> SessionProblem {
        let problem = SessionProblem(
            name: name, colorGrade: colorGrade, styles: Array(styles)
        )
        problem.skills = Array(skills)
        if !notes.isEmpty { problem.notes = notes }
        if let photoData {
            problem.photoFilename = try? savePhoto(photoData)
        }
        return problem
    }

    /// Writes the edited fields back onto an existing problem. Attempt counts
    /// and the session link belong to the problem, not the form, so they stay.
    func apply(to problem: SessionProblem,
               savePhoto: (Data) throws -> String,
               deletePhoto: (String) throws -> Void) {
        problem.name = name
        problem.colorGrade = colorGrade
        problem.styles = Array(styles)
        problem.skills = Array(skills)
        problem.notes = notes.isEmpty ? nil : notes
        replacePhoto(on: problem, savePhoto: savePhoto, deletePhoto: deletePhoto)
    }

    /// A replacement that cannot be written leaves the old photo in place; the
    /// rest of the edit is worth more than the new image.
    private func replacePhoto(on problem: SessionProblem,
                              savePhoto: (Data) throws -> String,
                              deletePhoto: (String) throws -> Void) {
        guard let photoData, photoData != storedPhoto?.bytes else { return }
        guard let filename = try? savePhoto(photoData) else { return }
        if let previousFilename = storedPhoto?.filename {
            try? deletePhoto(previousFilename)
        }
        problem.photoFilename = filename
    }
}

private struct StoredPhoto {
    let filename: String
    let bytes: Data?
}
