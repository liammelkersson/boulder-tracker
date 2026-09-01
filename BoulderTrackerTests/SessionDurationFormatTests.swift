import Testing
@testable import BoulderTracker

struct SessionDurationFormatTests {
    @Test func timerStringShowsHoursOnlyWhenNeeded() {
        #expect(SessionDurationFormat.timerString(from: 3 * 3600 + 21 * 60 + 5) == "3:21:05")
        #expect(SessionDurationFormat.timerString(from: 45 * 60) == "45:00")
        #expect(SessionDurationFormat.timerString(from: 7 * 60 + 3) == "07:03")
    }

    @Test func compactStringMatchesListStyle() {
        #expect(SessionDurationFormat.compactString(from: 100 * 60) == "1h 40m")
        #expect(SessionDurationFormat.compactString(from: 55 * 60) == "55m")
        #expect(SessionDurationFormat.compactString(from: 2 * 3600 + 5 * 60) == "2h 05m")
    }
}
