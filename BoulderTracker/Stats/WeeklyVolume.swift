import Foundation

/// Problems logged and sends recorded during one calendar week.
struct WeeklyVolume: Equatable {
    let weekStart: Date
    let problemCount: Int
    let sendCount: Int
}
