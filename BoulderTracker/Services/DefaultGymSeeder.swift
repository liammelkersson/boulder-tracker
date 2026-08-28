import Foundation
import SwiftData

enum DefaultGymSeeder {
    static let defaultGymName = "Klättervigören Jönköping"

    static func seedIfNeeded(context: ModelContext) throws {
        let existing = try context.fetchCount(FetchDescriptor<Gym>())
        guard existing == 0 else { return }
        context.insert(Gym(name: defaultGymName, isDefault: true))
        try context.save()
    }
}
