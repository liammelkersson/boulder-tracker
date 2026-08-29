import Foundation

struct StatsSummary: Equatable {
    var sessionCount = 0
    var totalDuration: TimeInterval = 0
    var problemCount = 0
    /// Successful tops: send logs + flash logs.
    var sendCount = 0
    /// Every logged go: flashes + sends + falls.
    var attemptCount = 0
    var flashCount = 0

    var completionRate: Double {
        attemptCount == 0 ? 0 : Double(sendCount) / Double(attemptCount)
    }

    var flashRate: Double {
        attemptCount == 0 ? 0 : Double(flashCount) / Double(attemptCount)
    }
}
