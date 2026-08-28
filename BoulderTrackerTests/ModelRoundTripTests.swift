import Testing
import SwiftData
@testable import BoulderTracker

@MainActor
func makeInMemoryContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: Session.self, ProblemAttempt.self, Gym.self, Partner.self,
        RoadmapProgress.self, Achievement.self,
        configurations: config
    )
}

@MainActor
struct ModelRoundTripTests {
    @Test func sessionRoundTripsWithAttempts() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let gym = Gym(name: "Klättervigören Jönköping", isDefault: true)
        let session = Session(startTime: .now, gym: gym, partners: [])
        let attempt = ProblemAttempt(
            colorGrade: .red, styles: [.overhang, .sloper],
            attemptCount: 3, result: .send
        )
        session.attempts.append(attempt)
        context.insert(session)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Session>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.attempts.count == 1)
        #expect(fetched.first?.attempts.first?.styles == [.overhang, .sloper])
        #expect(fetched.first?.gym?.name == "Klättervigören Jönköping")
    }

    @Test func deletingSessionCascadesToAttempts() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let session = Session(startTime: .now, gym: nil, partners: [])
        session.attempts.append(ProblemAttempt(
            colorGrade: .green, styles: [], attemptCount: 1, result: .flash
        ))
        context.insert(session)
        try context.save()

        context.delete(session)
        try context.save()

        let attempts = try context.fetch(FetchDescriptor<ProblemAttempt>())
        #expect(attempts.isEmpty)
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

    @Test func liveSessionHasNilEndTime() throws {
        let session = Session(startTime: .now, gym: nil, partners: [])
        #expect(session.isLive)
        session.endTime = .now
        #expect(!session.isLive)
    }
}
