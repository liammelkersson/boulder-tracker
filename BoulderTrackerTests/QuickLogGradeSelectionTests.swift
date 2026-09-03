import Testing
import Foundation
@testable import BoulderTracker

struct QuickLogGradeSelectionTests {
    private func problem(grade: ColorGrade, logs: Int) -> SessionProblem {
        SessionProblem(name: "", colorGrade: grade, styles: [], sendCount: logs)
    }

    @Test func emptySessionFallsBackToTheDefaultThree() {
        #expect(QuickLogGradeSelection.grades(for: []) == [.blue, .red, .black])
    }

    @Test func picksTheThreeMostLoggedGrades() {
        let problems = [
            problem(grade: .green, logs: 1),
            problem(grade: .blue, logs: 5),
            problem(grade: .red, logs: 3),
            problem(grade: .black, logs: 4),
        ]

        #expect(QuickLogGradeSelection.grades(for: problems) == [.blue, .black, .red])
    }

    @Test func sumsEveryProblemLoggedForAGrade() {
        let problems = [
            problem(grade: .green, logs: 2),
            problem(grade: .green, logs: 2),
            problem(grade: .blue, logs: 3),
            problem(grade: .red, logs: 1),
        ]

        #expect(QuickLogGradeSelection.grades(for: problems).first == .green)
    }

    @Test func breaksTiesByDisplayOrder() {
        let problems = [
            problem(grade: .black, logs: 2),
            problem(grade: .green, logs: 2),
            problem(grade: .red, logs: 2),
        ]

        #expect(QuickLogGradeSelection.grades(for: problems) == [.green, .red, .black])
    }

    @Test func padsWithDefaultsWhenFewerThanThreeGradesAreLogged() {
        let grades = QuickLogGradeSelection.grades(for: [problem(grade: .white, logs: 4)])

        #expect(grades.count == 3)
        #expect(grades.first == .white)
        #expect(Set(grades).count == 3)
    }

    @Test func ignoresGradesWithNoLogs() {
        let problems = [
            problem(grade: .white, logs: 0),
            problem(grade: .red, logs: 2),
        ]

        #expect(QuickLogGradeSelection.grades(for: problems).first == .red)
        #expect(!QuickLogGradeSelection.grades(for: problems).contains(.white))
    }
}
