import Testing
@testable import BoulderTracker

struct ColorGradeTests {
    @Test func gradesOrderEasiestToHardest() {
        #expect(ColorGrade.yellow < ColorGrade.green)
        #expect(ColorGrade.green < ColorGrade.blue)
        #expect(ColorGrade.blue < ColorGrade.red)
        #expect(ColorGrade.red < ColorGrade.black)
        #expect(ColorGrade.black < ColorGrade.white)
        #expect(ColorGrade.unknown < ColorGrade.yellow)
    }

    @Test func gradeRangesMatchGymScale() {
        #expect(ColorGrade.green.frenchRange == "4–5")
        #expect(ColorGrade.green.vGradeRange == "V0–V2")
        #expect(ColorGrade.white.frenchRange == "7C+")
        #expect(ColorGrade.white.vGradeRange == "V9+")
        #expect(ColorGrade.yellow.vGradeShort == "WU")
    }

    @Test func allSevenGradesExist() {
        #expect(ColorGrade.allCases.count == 7)
        #expect(ColorGrade.displayOrder.count == 7)
    }
}
