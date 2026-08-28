import SwiftUI
import SwiftData

@main
struct BoulderTrackerApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: Session.self, ProblemAttempt.self, Gym.self, Partner.self,
                RoadmapProgress.self, Achievement.self
            )
            try DefaultGymSeeder.seedIfNeeded(context: container.mainContext)
        } catch {
            fatalError("Failed to initialize model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(container)
    }
}
