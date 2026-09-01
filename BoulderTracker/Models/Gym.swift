import Foundation
import SwiftData

@Model
final class Gym {
    var name: String = ""
    var isDefault: Bool = false
    /// Explicit inverse: CloudKit-backed stores require one on every
    /// relationship. Deleting a gym nulls out `Session.gym`.
    @Relationship(deleteRule: .nullify, inverse: \Session.gym)
    var sessions: [Session]? = []

    init(name: String, isDefault: Bool = false) {
        self.name = name
        self.isDefault = isDefault
    }
}
