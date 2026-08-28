import Testing
@testable import BoulderTracker

struct SessionDurationFormatTests {
    @Test func formatsHoursMinutesSeconds() {
        #expect(SessionDurationFormat.string(from: 3 * 3600 + 21 * 60 + 5) == "3:21:05")
        #expect(SessionDurationFormat.string(from: 45 * 60) == "0:45:00")
    }
}
