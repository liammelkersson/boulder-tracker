import Testing
import Foundation
import SwiftData
@testable import BoulderTracker

@MainActor
struct ProblemDraftTests {
    private func neverSavesAPhoto(_ photoData: Data) throws -> String {
        Issue.record("A draft without photo data must not touch the photo store")
        return ""
    }

    @Test func makeProblemCarriesEveryEnteredField() {
        var draft = ProblemDraft()
        draft.name = "Elektra"
        draft.colorGrade = .red
        draft.styles = [.crimp]
        draft.skills = [.cross]
        draft.notes = "Left heel hook"

        let problem = draft.makeProblem(savePhoto: neverSavesAPhoto)

        #expect(problem.name == "Elektra")
        #expect(problem.colorGrade == .red)
        #expect(problem.styles == [.crimp])
        #expect(problem.skills == [.cross])
        #expect(problem.notes == "Left heel hook")
        #expect(problem.photoFilename == nil)
    }

    @Test func makeProblemLeavesEmptyNotesUnset() {
        let problem = ProblemDraft().makeProblem(savePhoto: neverSavesAPhoto)

        #expect(problem.notes == nil)
    }

    @Test func makeProblemStoresPhotoDataAndKeepsTheFilename() {
        var draft = ProblemDraft()
        draft.photoData = Data([0x01, 0x02])
        var savedBytes: Data?

        let problem = draft.makeProblem { photoData in
            savedBytes = photoData
            return "problem-photo.jpg"
        }

        #expect(savedBytes == Data([0x01, 0x02]))
        #expect(problem.photoFilename == "problem-photo.jpg")
    }

    private func neverDeletesAPhoto(_ filename: String) throws {
        Issue.record("An unchanged photo must not be deleted")
    }

    @Test func draftFromAStoredProblemCarriesEveryField() {
        let problem = SessionProblem(
            name: "Elektra", colorGrade: .red, styles: [.crimp, .overhang]
        )
        problem.notes = "Left heel hook"
        problem.photoFilename = "stored.jpg"
        problem.skills = [.flagging, .smear]

        let draft = ProblemDraft(problem: problem) { _ in Data([0x09]) }

        #expect(draft.name == "Elektra")
        #expect(draft.colorGrade == .red)
        #expect(draft.styles == [.crimp, .overhang])
        #expect(draft.skills == [.flagging, .smear])
        #expect(draft.notes == "Left heel hook")
        #expect(draft.photoData == Data([0x09]))
    }

    @Test func draftFromAProblemLinkedToAProjectIsMarkedAsProject() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let problem = SessionProblem(name: "Elektra", colorGrade: .red, styles: [])
        context.insert(problem)
        problem.project = Project(name: "Elektra")

        let draft = ProblemDraft(problem: problem) { _ in nil }

        #expect(draft.isProject)
    }

    @Test func applyWritesEditedFieldsBackToTheProblem() {
        let problem = SessionProblem(name: "Elektra", colorGrade: .red, styles: [.crimp])
        var draft = ProblemDraft(problem: problem) { _ in nil }
        draft.name = "Elektra Sit"
        draft.colorGrade = .black
        draft.styles = [.sloper, .roof]
        draft.skills = [.deadpoint]
        draft.notes = "New beta"

        draft.apply(to: problem, savePhoto: neverSavesAPhoto, deletePhoto: neverDeletesAPhoto)

        #expect(problem.name == "Elektra Sit")
        #expect(problem.colorGrade == .black)
        #expect(Set(problem.styles) == [.sloper, .roof])
        #expect(problem.skills == [.deadpoint])
        #expect(problem.notes == "New beta")
    }

    @Test func applyUnsetsNotesThatWereCleared() {
        let problem = SessionProblem(name: "Elektra", colorGrade: .red, styles: [])
        problem.notes = "Old beta"
        var draft = ProblemDraft(problem: problem) { _ in nil }
        draft.notes = ""

        draft.apply(to: problem, savePhoto: neverSavesAPhoto, deletePhoto: neverDeletesAPhoto)

        #expect(problem.notes == nil)
    }

    @Test func applyKeepsAPhotoThatWasNotReplaced() {
        let problem = SessionProblem(name: "Elektra", colorGrade: .red, styles: [])
        problem.photoFilename = "stored.jpg"
        var draft = ProblemDraft(problem: problem) { _ in Data([0x09]) }
        draft.name = "Elektra Sit"

        draft.apply(to: problem, savePhoto: neverSavesAPhoto, deletePhoto: neverDeletesAPhoto)

        #expect(problem.photoFilename == "stored.jpg")
    }

    @Test func applyStoresAReplacementPhotoAndRemovesTheOldFile() {
        let problem = SessionProblem(name: "Elektra", colorGrade: .red, styles: [])
        problem.photoFilename = "stored.jpg"
        var draft = ProblemDraft(problem: problem) { _ in Data([0x09]) }
        draft.photoData = Data([0x0A])
        var deletedFilename: String?

        draft.apply(
            to: problem,
            savePhoto: { _ in "replacement.jpg" },
            deletePhoto: { filename in deletedFilename = filename }
        )

        #expect(problem.photoFilename == "replacement.jpg")
        #expect(deletedFilename == "stored.jpg")
    }

    @Test func applyKeepsTheStoredPhotoWhenTheReplacementCannotBeWritten() {
        let problem = SessionProblem(name: "Elektra", colorGrade: .red, styles: [])
        problem.photoFilename = "stored.jpg"
        var draft = ProblemDraft(problem: problem) { _ in Data([0x09]) }
        draft.photoData = Data([0x0A])

        draft.apply(
            to: problem,
            savePhoto: { _ in throw PhotoStoreStubError.unwritable },
            deletePhoto: neverDeletesAPhoto
        )

        #expect(problem.photoFilename == "stored.jpg")
    }

    @Test func makeProblemSurvivesAFailingPhotoStore() {
        var draft = ProblemDraft()
        draft.name = "Elektra"
        draft.photoData = Data([0x01])

        let problem = draft.makeProblem { _ in throw PhotoStoreStubError.unwritable }

        #expect(problem.name == "Elektra")
        #expect(problem.photoFilename == nil)
    }
}

private enum PhotoStoreStubError: Error {
    case unwritable
}
