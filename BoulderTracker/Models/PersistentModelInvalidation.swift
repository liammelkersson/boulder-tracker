import SwiftData

extension PersistentModel {
    /// True once the row is gone from the store. Views observing a model get
    /// one final body evaluation after a delete + save; touching any persisted
    /// property there traps in SwiftData, so they must bail out on this first.
    var isInvalidated: Bool {
        isDeleted || modelContext == nil
    }
}

extension Array where Element: PersistentModel {
    /// Drops rows already deleted from the store; see `isInvalidated`.
    var persisted: [Element] {
        filter { !$0.isInvalidated }
    }
}
