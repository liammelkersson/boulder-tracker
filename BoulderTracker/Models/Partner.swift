import Foundation
import SwiftData

@Model
final class Partner {
    var name: String = ""
    /// Inverse of `Session.partners` (declared on the session side); CloudKit
    /// requires the optional type. Deleting a partner drops it from sessions.
    var sessions: [Session]? = []

    init(name: String) {
        self.name = name
    }
}
