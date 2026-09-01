import Foundation
import SwiftData

@Model
final class RoadmapProgress {
    // No `.unique` constraint: CloudKit-backed stores reject them.
    var itemID: String = ""
    var checkedAt: Date = Date.now

    init(itemID: String, checkedAt: Date = .now) {
        self.itemID = itemID
        self.checkedAt = checkedAt
    }
}
