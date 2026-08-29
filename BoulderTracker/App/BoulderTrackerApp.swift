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
                RoadmapProgress.self, Achievement.self
            )
            try DefaultGymSeeder.seedIfNeeded(context: container.mainContext)
        } catch {
            fatalError("Failed to initialize model container: \(error)")
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
