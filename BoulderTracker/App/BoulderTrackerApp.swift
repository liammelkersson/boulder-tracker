import OSLog
import SwiftUI
import SwiftData

@main
struct BoulderTrackerApp: App {
    let container: ModelContainer
    private let syncCoordinator: PhoneSyncCoordinator

    init() {
        do {
            container = try ModelContainer(
                for: Session.self, SessionProblem.self, Gym.self, Partner.self,
                RoadmapProgress.self, Achievement.self, Shoe.self
            )
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

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(syncCoordinator)
                .task { syncCoordinator.start() }
        }
        .modelContainer(container)
    }
}
