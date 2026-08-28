import Foundation

struct StatsSummary: Equatable {
    var sessionCount = 0
    var totalDuration: TimeInterval = 0
    var problemCount = 0
    var sendCount = 0
    var attemptCount = 0
    var flashCount = 0

    var completionRate: Double {
        problemCount == 0 ? 0 : Double(sendCount) / Double(problemCount)
    }

    var flashRate: Double {
        problemCount == 0 ? 0 : Double(flashCount) / Double(problemCount)
    }
}
