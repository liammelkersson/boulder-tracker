import Testing
import Foundation
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
        draft.notes = "Left heel hook"

        let problem = draft.makeProblem(savePhoto: neverSavesAPhoto)

        #expect(problem.name == "Elektra")
        #expect(problem.colorGrade == .red)
        #expect(problem.styles == [.crimp])
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
