import OSLog
import SwiftData

extension ModelContext {
    /// Saves and logs any failure. UI flows have no rethrow path, so the log
    /// is the only surface for a store-level failure.
    func saveReportingFailure(operation: String) {
        do {
            try save()
        } catch {
            Logger.persistence.error("Save failed during \(operation): \(error)")
        }
    }
}
