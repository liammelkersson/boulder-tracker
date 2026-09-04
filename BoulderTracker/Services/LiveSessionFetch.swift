import Foundation
import SwiftData

/// The one in-progress session, if any. A session is live while it has no end
/// time; the newest wins, so a stale unfinished row can never shadow today's.
enum LiveSessionFetch {
    static func current(in context: ModelContext) -> Session? {
        var descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.endTime == nil },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }
}
