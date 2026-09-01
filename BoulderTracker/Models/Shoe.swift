import Foundation
import SwiftData

@Model
final class Shoe {
    var name: String
    var isRetired: Bool = false
    var isSampleData: Bool = false
    /// Stable identity across devices; see the note on `Session.syncID`.
    var syncID: UUID?
    /// Explicit inverse so deleting a pair nulls out `Session.shoe`.
    @Relationship(deleteRule: .nullify, inverse: \Session.shoe)
    var sessions: [Session] = []

    init(name: String, isRetired: Bool = false) {
        self.name = name
        self.isRetired = isRetired
        self.syncID = UUID()
    }
}
