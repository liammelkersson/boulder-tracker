import Testing
import Foundation
import SwiftData
@testable import BoulderTracker

@MainActor
struct SampleDataGeneratorTests {
    private let referenceDate = ISO8601DateFormatter().date(from: "2026-08-26T12:00:00Z")!

    @Test func insertCreatesFlaggedFinishedSessionsWithinThreeMonths() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        try SampleDataGenerator.insertSampleData(into: context, referenceDate: referenceDate)

        let sessions = try context.fetch(FetchDescriptor<Session>())
        #expect(sessions.count >= 15)
        let allFlaggedAsSample = sessions.allSatisfy(\.isSampleData)
        #expect(allFlaggedAsSample)
        let allFinished = sessions.allSatisfy { !$0.isLive }
        #expect(allFinished)
        let earliestAllowed = referenceDate.addingTimeInterval(-93 * 24 * 3600)
        let allWithinPeriod = sessions.allSatisfy {
            $0.startTime >= earliestAllowed && $0.startTime <= referenceDate
        }
        #expect(allWithinPeriod)
        let allHaveProblems = sessions.allSatisfy { !$0.problems.isEmpty }
        #expect(allHaveProblems)
    }

    @Test func insertedProblemsCoverStylesIncludingDyno() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        try SampleDataGenerator.insertSampleData(into: context, referenceDate: referenceDate)

        let sessions = try context.fetch(FetchDescriptor<Session>())
        let styles = Set(sessions.flatMap(\.problems).flatMap(\.styles))
        #expect(styles.contains(.dyno))
        #expect(styles.count >= 4)
    }

    @Test func insertCreatesSampleShoe() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        try SampleDataGenerator.insertSampleData(into: context, referenceDate: referenceDate)

        let shoes = try context.fetch(FetchDescriptor<Shoe>())
        let anySampleShoe = shoes.contains(where: \.isSampleData)
        #expect(anySampleShoe)
        let sessions = try context.fetch(FetchDescriptor<Session>())
        let anySessionHasShoe = sessions.contains { $0.shoe != nil }
        #expect(anySessionHasShoe)
    }

    @Test func removeDeletesOnlySampleData() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let realSession = Session(startTime: referenceDate, gym: nil, partners: [])
        realSession.endTime = referenceDate.addingTimeInterval(3600)
        context.insert(realSession)
        let realShoe = Shoe(name: "My Actual Shoe")
        context.insert(realShoe)
        try SampleDataGenerator.insertSampleData(into: context, referenceDate: referenceDate)

        try SampleDataGenerator.removeSampleData(from: context)

        let sessions = try context.fetch(FetchDescriptor<Session>())
        #expect(sessions.count == 1)
        #expect(sessions.first?.isSampleData == false)
        let shoes = try context.fetch(FetchDescriptor<Shoe>())
        #expect(shoes.count == 1)
        #expect(shoes.first?.name == "My Actual Shoe")
        let problems = try context.fetch(FetchDescriptor<SessionProblem>())
        #expect(problems.isEmpty)
    }

    @Test func sampleDataExistsReflectsInsertAndRemove() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        #expect(!SampleDataGenerator.sampleDataExists(in: context))
        try SampleDataGenerator.insertSampleData(into: context, referenceDate: referenceDate)
        #expect(SampleDataGenerator.sampleDataExists(in: context))
        try SampleDataGenerator.removeSampleData(from: context)
        #expect(!SampleDataGenerator.sampleDataExists(in: context))
    }
}
