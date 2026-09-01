import Testing
@testable import BoulderTracker

struct GradeSystemTests {
    @Test func onlyFontAndVScaleAreSelectable() {
        #expect(GradeSystem.allCases == [.french, .vScale])
    }

    @Test func fontIsTheDefaultSystem() {
        #expect(GradeSystem.default == .french)
    }

    @Test func legacyColourValueNoLongerDecodes() {
        #expect(GradeSystem(rawValue: "color") == nil)
    }
}
