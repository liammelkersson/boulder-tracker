import OSLog
import SwiftUI
import SwiftData

@main
struct BoulderTrackerApp: App {
    let container: ModelContainer
    private let syncCoordinator: PhoneSyncCoordinator
    private let activityPresenter: SessionActivityPresenter
    /// `SessionSendLog.writer` is weak, so the app owns the only strong
    /// reference for as long as it runs.
    private let logWriter: SessionLogWriter

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
        AchievementCleanup.removeUnearnedOnce(context: container.mainContext, defaults: .standard)
        ProjectBackfill.runIfNeeded(context: container.mainContext, defaults: .standard)
        Self.resetOnboardingForUITestingIfRequested(defaults: .standard)
        syncCoordinator = PhoneSyncCoordinator(context: container.mainContext)
        activityPresenter = SessionActivityPresenter()
        logWriter = Self.makeLogWriter(
            context: container.mainContext,
            syncCoordinator: syncCoordinator,
            activityPresenter: activityPresenter
        )
        SessionSendLog.writer = logWriter
        Self.refreshActivityOnWatchLogs(
            context: container.mainContext,
            syncCoordinator: syncCoordinator,
            activityPresenter: activityPresenter
        )
    }

    private static func makeLogWriter(
        context: ModelContext,
        syncCoordinator: PhoneSyncCoordinator,
        activityPresenter: SessionActivityPresenter
    ) -> SessionLogWriter {
        SessionLogWriter(
            context: context,
            announceAttempt: { problem, session, result in
                syncCoordinator.announceAttempt(on: problem, in: session, result: result)
            },
            refreshActivity: { session in activityPresenter.refresh(for: session) }
        )
    }

    private static func refreshActivityOnWatchLogs(
        context: ModelContext,
        syncCoordinator: PhoneSyncCoordinator,
        activityPresenter: SessionActivityPresenter
    ) {
        syncCoordinator.onInboundEventApplied = {
            guard let live = LiveSessionFetch.current(in: context) else { return }
            activityPresenter.refresh(for: live)
        }
    }

    /// XCUITest launches pass `-uiTestingResetOnboarding YES`, which lands in
    /// the argument domain, so every UI run starts at the wizard.
    private static func resetOnboardingForUITestingIfRequested(defaults: UserDefaults) {
        guard defaults.bool(forKey: AppPreferences.uiTestingResetOnboardingKey) else { return }
        defaults.set(false, forKey: AppPreferences.onboardingCompleteKey)
    }

    /// CloudKit first for cross-device backup; falls back to a device-local
    /// store when iCloud is unavailable (no account, missing capability).
    private static func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Session.self, SessionProblem.self, Gym.self, Partner.self,
            RoadmapProgress.self, Achievement.self, Shoe.self, Project.self,
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
            AppRootView()
                .environment(syncCoordinator)
                .environment(activityPresenter)
                .task { syncCoordinator.start() }
        }
        .modelContainer(container)
    }
}
