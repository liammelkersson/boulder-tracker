import Foundation
import SwiftData

@Model
final class RoadmapProgress {
    @Attribute(.unique) var itemID: String
    var checkedAt: Date

    init(itemID: String, checkedAt: Date = .now) {
        self.itemID = itemID
        self.checkedAt = checkedAt
    }
}
