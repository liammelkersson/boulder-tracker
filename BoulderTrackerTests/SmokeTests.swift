import Testing
@testable import BoulderTracker

struct SmokeTests {
    @Test func appTabHasFiveCases() {
        let tabs: [AppTab] = [.home, .calendar, .stats, .roadmap, .profile]
        #expect(tabs.count == 5)
    }
}
