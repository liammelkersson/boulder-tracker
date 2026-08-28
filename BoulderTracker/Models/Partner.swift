import Foundation
import SwiftData

@Model
final class Partner {
    var name: String

    init(name: String) {
        self.name = name
    }
}
