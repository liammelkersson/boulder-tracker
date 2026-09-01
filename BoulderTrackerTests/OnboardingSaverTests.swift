import Foundation
import SwiftData
import Testing
@testable import BoulderTracker

@MainActor
struct OnboardingSaverTests {
    @Test func existingGymBecomesDefaultAndProfilePreferencesAreSaved() throws {
        let fixture = try makeFixture()
        let previousDefault = Gym(name: "Old Gym", isDefault: true)
        let selectedGym = Gym(name: "Bloc House")
        fixture.context.insert(previousDefault)
        fixture.context.insert(selectedGym)
        try fixture.context.save()

        var draft = validDraft()
        draft.gymChoice = .existing(selectedGym.persistentModelID)
        draft.gradeSystem = .vScale
        draft.shoeName = "  Scarpa Drago  "

        try fixture.saver.save(
            draft,
            gyms: [previousDefault, selectedGym],
            context: fixture.context
        )

        #expect(selectedGym.isDefault)
        #expect(!previousDefault.isDefault)
        #expect(fixture.defaults.string(forKey: AppPreferences.profileNameKey) == "Liam")
        #expect(fixture.defaults.string(forKey: AppPreferences.climbingSinceYearKey) == "2024")
        #expect(fixture.defaults.string(forKey: AppPreferences.gradeSystemKey) == "vScale")
        #expect(fixture.defaults.bool(forKey: AppPreferences.onboardingCompleteKey))

        let shoes = try fixture.context.fetch(FetchDescriptor<Shoe>())
        #expect(shoes.map(\.name) == ["Scarpa Drago"])
    }

    @Test func customGymIsCreatedAsOnlyDefault() throws {
        let fixture = try makeFixture()
        let oldGym = Gym(name: "Old Gym", isDefault: true)
        fixture.context.insert(oldGym)
        try fixture.context.save()

        var draft = validDraft()
        draft.gymChoice = .custom
        draft.customGymName = "  New Depot  "

        try fixture.saver.save(draft, gyms: [oldGym], context: fixture.context)

        let gyms = try fixture.context.fetch(FetchDescriptor<Gym>())
        #expect(gyms.count == 2)
        #expect(gyms.filter(\.isDefault).map(\.name) == ["New Depot"])
    }

    @Test func emptyShoeDoesNotCreateShoe() throws {
        let fixture = try makeFixture()
        let gym = Gym(name: "Home Wall")
        fixture.context.insert(gym)
        try fixture.context.save()

        var draft = validDraft()
        draft.gymChoice = .existing(gym.persistentModelID)
        draft.shoeName = "  "

        try fixture.saver.save(draft, gyms: [gym], context: fixture.context)

        #expect(try fixture.context.fetch(FetchDescriptor<Shoe>()).isEmpty)
    }

    @Test func photoFailureRollsBackModelsAndLeavesCompletionFalse() throws {
        let fixture = try makeFixture(savePhoto: { _ in throw TestFailure.photoWrite })
        let gym = Gym(name: "Home Wall", isDefault: true)
        fixture.context.insert(gym)
        try fixture.context.save()

        var draft = validDraft()
        draft.gymChoice = .custom
        draft.customGymName = "New Gym"
        draft.shoeName = "Drago"
        draft.avatarData = Data([0xFF, 0xD8])

        #expect(throws: TestFailure.self) {
            try fixture.saver.save(draft, gyms: [gym], context: fixture.context)
        }

        #expect(!fixture.defaults.bool(forKey: AppPreferences.onboardingCompleteKey))
        #expect(try fixture.context.fetch(FetchDescriptor<Shoe>()).isEmpty)
        let gyms = try fixture.context.fetch(FetchDescriptor<Gym>())
        #expect(gyms.count == 1)
        #expect(gyms.first?.name == "Home Wall")
        #expect(gyms.first?.isDefault == true)
    }

    private enum TestFailure: Error {
        case photoWrite
    }

    private struct Fixture {
        let container: ModelContainer
        let context: ModelContext
        let defaults: UserDefaults
        let saver: OnboardingSaver
    }

    private func makeFixture(
        savePhoto: @escaping (Data) throws -> String = { _ in "avatar.jpg" }
    ) throws -> Fixture {
        let container = try makeInMemoryContainer()
        let suiteName = "OnboardingSaverTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let saver = OnboardingSaver(
            defaults: defaults,
            savePhoto: savePhoto,
            deletePhoto: { _ in }
        )
        return Fixture(
            container: container,
            context: container.mainContext,
            defaults: defaults,
            saver: saver
        )
    }

    private func validDraft() -> OnboardingDraft {
        var draft = OnboardingDraft()
        draft.name = "  Liam  "
        draft.climbingSinceYear = "2024"
        return draft
    }
}
