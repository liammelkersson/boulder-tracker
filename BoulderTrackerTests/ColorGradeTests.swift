import Testing
@testable import BoulderTracker

struct ColorGradeTests {
    @Test func gradesOrderEasiestToHardest() {
        #expect(ColorGrade.green < ColorGrade.blue)
        #expect(ColorGrade.blue < ColorGrade.red)
        #expect(ColorGrade.red < ColorGrade.black)
        #expect(ColorGrade.black < ColorGrade.white)
        #expect(ColorGrade.white < ColorGrade.yellow)
    }

    @Test func gradeRangesMatchGymScale() {
        #expect(ColorGrade.green.frenchRange == "4–5b")
        #expect(ColorGrade.green.vGradeRange == "V0–V1")
        #expect(ColorGrade.yellow.frenchRange == "8a+")
        #expect(ColorGrade.yellow.vGradeRange == "V11+")
    }

    @Test func allSixGradesExist() {
        #expect(ColorGrade.allCases.count == 6)
    }
}
