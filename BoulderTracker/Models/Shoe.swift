import Foundation
import SwiftData

@Model
final class Shoe {
    var name: String = ""
    var isRetired: Bool = false
    var isSampleData: Bool = false
    /// Explicit inverse so deleting a pair nulls out `Session.shoe`;
    /// optional because CloudKit-backed stores require it.
    @Relationship(deleteRule: .nullify, inverse: \Session.shoe)
    var sessions: [Session]? = []

    init(name: String, isRetired: Bool = false) {
        self.name = name
        self.isRetired = isRetired
    }
}
