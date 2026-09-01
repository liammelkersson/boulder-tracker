import OSLog
import SwiftUI
import SwiftData

@main
struct BoulderTrackerApp: App {
    let container: ModelContainer
    private let syncCoordinator: PhoneSyncCoordinator

    init() {
        do {
            container = try Self.makeContainer()
        } catch {
            fatalError("Failed to initialize model container: \(error)")
        }
        do {
            try DefaultGymSeeder.seedIfNeeded(context: container.mainContext)
        } catch {
            // The app works without a seeded gym; the user can add one manually.
            Logger.persistence.error("Default gym seeding failed: \(error)")
        }
        syncCoordinator = PhoneSyncCoordinator(context: container.mainContext)
    }

    /// CloudKit first for cross-device backup; falls back to a device-local
    /// store when iCloud is unavailable (no account, missing capability).
    private static func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Session.self, SessionProblem.self, Gym.self, Partner.self,
            RoadmapProgress.self, Achievement.self, Shoe.self,
        ])
        do {
            return try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            )
        } catch {
            Logger.persistence.error("CloudKit container unavailable, using local store: \(error)")
            return try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(syncCoordinator)
                .task { syncCoordinator.start() }
        }
        .modelContainer(container)
    }
}
