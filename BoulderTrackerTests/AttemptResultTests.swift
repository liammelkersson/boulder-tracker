import Testing
@testable import BoulderTracker

struct AttemptResultTests {
    @Test func flashAndSendCountAsSends() {
        #expect(AttemptResult.flash.countsAsSend)
        #expect(AttemptResult.send.countsAsSend)
        #expect(!AttemptResult.project.countsAsSend)
    }
}
