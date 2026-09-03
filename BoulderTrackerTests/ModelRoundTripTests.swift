import Testing
import Foundation
import SwiftData
@testable import BoulderTracker

@MainActor
func makeInMemoryContainer() throws -> ModelContainer {
    // The test host carries iCloud entitlements, so `.automatic` would try
    // CloudKit; tests must stay on a plain in-memory store.
    let schema = Schema([
        Session.self, SessionProblem.self, Gym.self, Partner.self,
        RoadmapProgress.self, Achievement.self, Shoe.self, Project.self,
    ])
    let config = ModelConfiguration(
        schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none
    )
    return try ModelContainer(for: schema, configurations: config)
}

@MainActor
struct ModelRoundTripTests {
    @Test func sessionRoundTripsWithProblems() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let gym = Gym(name: "Klättervigören Jönköping", isDefault: true)
        let session = Session(startTime: .now, gym: gym, partners: [], climbType: .topRope)
        let problem = SessionProblem(
            name: "The Roof", colorGrade: .red, styles: [.overhang, .sloper],
            flashCount: 0, sendCount: 1, fallCount: 3
        )
        session.problems.append(problem)
        context.insert(session)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Session>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.problems.count == 1)
        #expect(fetched.first?.problems.first?.styles == [.overhang, .sloper])
        #expect(fetched.first?.problems.first?.name == "The Roof")
        #expect(fetched.first?.climbType == .topRope)
        #expect(fetched.first?.gym?.name == "Klättervigören Jönköping")
    }

    @Test func deletingSessionCascadesToProblems() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let session = Session(startTime: .now, gym: nil, partners: [])
        session.problems.append(SessionProblem(
            name: "Warm Up", colorGrade: .green, styles: [], flashCount: 1
        ))
        context.insert(session)
        try context.save()

        context.delete(session)
        try context.save()

        let problems = try context.fetch(FetchDescriptor<SessionProblem>())
        #expect(problems.isEmpty)
    }

    @Test func seederInsertsDefaultGymOnce() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        try DefaultGymSeeder.seedIfNeeded(context: context)
        try DefaultGymSeeder.seedIfNeeded(context: context)

        let gyms = try context.fetch(FetchDescriptor<Gym>())
        #expect(gyms.count == 1)
        #expect(gyms.first?.isDefault == true)
    }

    @Test func newSessionsAndProblemsGetSyncIdentities() throws {
        let session = Session(startTime: .now, gym: nil, partners: [])
        let problem = SessionProblem(name: "", colorGrade: .blue, styles: [])

        #expect(session.syncID != nil)
        #expect(problem.syncID != nil)
        #expect(session.syncID != problem.syncID)
        #expect(!session.isWatchTracked)
        #expect(session.appliedEventIDs.isEmpty)
    }

    @Test func heartRateSummaryRoundTrips() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let session = Session(startTime: .now, gym: nil, partners: [])
        session.avgHeartRate = 138
        session.maxHeartRate = 176
        session.activeCalories = 512
        session.isWatchTracked = true
        session.appliedEventIDs = [UUID()]
        context.insert(session)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Session>()).first
        #expect(fetched?.avgHeartRate == 138)
        #expect(fetched?.maxHeartRate == 176)
        #expect(fetched?.activeCalories == 512)
        #expect(fetched?.isWatchTracked == true)
        #expect(fetched?.appliedEventIDs.count == 1)
    }

    @Test func liveSessionHasNilEndTime() throws {
        let session = Session(startTime: .now, gym: nil, partners: [])
        #expect(session.isLive)
        session.endTime = .now
        #expect(!session.isLive)
    }

    @Test func projectRoundTripsWithLinkedProblem() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let gym = Gym(name: "Klätterverket")
        context.insert(gym)
        let session = Session(startTime: .now, gym: gym, partners: [])
        let problem = SessionProblem(name: "Elektra", colorGrade: .red, styles: [.crimp])
        session.problems = [problem]
        context.insert(session)
        let project = Project(name: "Elektra", colorGrade: .red, gym: gym)
        context.insert(project)
        problem.project = project
        try context.save()

        let stored = try context.fetch(FetchDescriptor<Project>())
        #expect(stored.count == 1)
        #expect(stored.first?.status == .active)
        #expect(stored.first?.isCurrent == false)
        #expect(stored.first?.problems?.first?.name == "Elektra")
        #expect(problem.project?.gym?.name == "Klätterverket")
    }

    @Test func markSentIfActiveOnlyMovesActiveProjects() {
        let active = Project(name: "Elektra")
        active.markSentIfActive()
        #expect(active.status == .sent)

        let archived = Project(name: "Old Wall", status: .archived)
        archived.markSentIfActive()
        #expect(archived.status == .archived)
    }
}
