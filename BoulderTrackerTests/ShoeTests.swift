import Testing
import Foundation
import SwiftData
@testable import BoulderTracker

@MainActor
struct ShoeTests {
    @Test func shoeRoundTripsOnSession() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let shoe = Shoe(name: "Scarpa Instinct VS")
        context.insert(shoe)
        let session = Session(startTime: .now, gym: nil, partners: [])
        session.shoe = shoe
        context.insert(session)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Session>()).first
        #expect(fetched?.shoe?.name == "Scarpa Instinct VS")
        #expect(fetched?.shoe?.isRetired == false)
    }

    @Test func newShoeGetsSyncIdentity() {
        #expect(Shoe(name: "Drago").syncID != nil)
    }

    @Test func sessionDefaultsToNoShoeAndRealData() {
        let session = Session(startTime: .now, gym: nil, partners: [])
        #expect(session.shoe == nil)
        #expect(!session.isSampleData)
    }

    @Test func deletedAndSavedSessionReportsInvalidated() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let session = Session(startTime: .now, gym: nil, partners: [])
        context.insert(session)
        try context.save()
        #expect(!session.isInvalidated)

        context.delete(session)
        try context.save()

        #expect(session.isInvalidated)
    }

    @Test func deletingShoeKeepsSession() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let shoe = Shoe(name: "La Sportiva Solution")
        context.insert(shoe)
        let session = Session(startTime: .now, gym: nil, partners: [])
        session.shoe = shoe
        context.insert(session)
        try context.save()

        context.delete(shoe)
        try context.save()

        let sessions = try context.fetch(FetchDescriptor<Session>())
        #expect(sessions.count == 1)
        #expect(sessions.first?.shoe == nil)
    }
}
