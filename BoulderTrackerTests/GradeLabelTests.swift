import Testing
@testable import BoulderTracker

struct GradeLabelTests {
    @Test func colorSystemKeepsTodaysStrings() {
        #expect(ColorGrade.red.shortLabel(in: .color) == "Red")
        #expect(ColorGrade.red.detailLabel(in: .color) == "Red · 6B–6C")
    }

    @Test func frenchSystemUsesFontGrades() {
        #expect(ColorGrade.red.shortLabel(in: .french) == "6B")
        #expect(ColorGrade.red.detailLabel(in: .french) == "6B–6C")
    }

    @Test func vScaleSystemUsesVGrades() {
        #expect(ColorGrade.red.shortLabel(in: .vScale) == "V5")
        #expect(ColorGrade.red.detailLabel(in: .vScale) == "V5–V6")
    }

    @Test func everyGradeHasNonEmptyLabelsInEverySystem() {
        for grade in ColorGrade.allCases {
            for system in GradeSystem.allCases {
                #expect(!grade.shortLabel(in: system).isEmpty)
                #expect(!grade.detailLabel(in: system).isEmpty)
            }
        }
    }

    @Test func shortLabelsAreDistinctWithinASystem() {
        for system in GradeSystem.allCases {
            let labels = ColorGrade.allCases.map { $0.shortLabel(in: system) }
            #expect(Set(labels).count == labels.count)
        }
    }

    @Test func unknownGradeStaysLegible() {
        #expect(ColorGrade.unknown.shortLabel(in: .vScale) == "?")
        #expect(ColorGrade.unknown.shortLabel(in: .french) == "?")
        #expect(ColorGrade.unknown.shortLabel(in: .color) == "Unknown")
    }
}
