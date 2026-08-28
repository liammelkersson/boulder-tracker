import Foundation
import SwiftData

@Model
final class Gym {
    var name: String
    var isDefault: Bool

    init(name: String, isDefault: Bool = false) {
        self.name = name
        self.isDefault = isDefault
    }
}
