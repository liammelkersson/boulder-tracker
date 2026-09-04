import Testing
import Foundation
import SwiftData
@testable import BoulderTracker

@MainActor
struct ProjectBackfillTests {
    private func makeSession(daysAgo: Int, gym: Gym?, context: ModelContext) -> Session {
        let start = Date.now.addingTimeInterval(TimeInterval(-daysAgo) * 24 * 3600)
        let session = Session(startTime: start, gym: gym, partners: [])
        context.insert(session)
        return session
    }

    @Test func createsOneProjectPerDerivedGroupAndClearsTheLegacyFlag() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let gym = Gym(name: "Klätterverket")
        context.insert(gym)
        let session = makeSession(daysAgo: 3, gym: gym, context: context)
        let marked = SessionProblem(name: "Elektra", colorGrade: .red, styles: [])
        marked.isProject = true
        let repeated = SessionProblem(name: "Moonwalk", colorGrade: .blue, styles: [], fallCount: 3)
        let ignored = SessionProblem(name: "Warmup", colorGrade: .green, styles: [], sendCount: 1)
        session.problems = [marked, repeated, ignored]
        try context.save()

        try ProjectBackfill.backfillProjects(in: context)

        let projects = try context.fetch(FetchDescriptor<Project>())
        #expect(Set(projects.map(\.name)) == ["Elektra", "Moonwalk"])
        #expect(projects.allSatisfy { $0.gym?.name == "Klätterverket" })
        #expect(projects.allSatisfy { $0.status == .active })
        #expect(marked.project?.name == "Elektra")
        #expect(marked.isProject == false)
        #expect(ignored.project == nil)
    }

    @Test func marksSentGroupsAsSent() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let session = makeSession(daysAgo: 1, gym: nil, context: context)
        let problem = SessionProblem(name: "Elektra", colorGrade: .red, styles: [],
                                     sendCount: 1, fallCount: 4)
        problem.isProject = true
        session.problems = [problem]
        try context.save()

        try ProjectBackfill.backfillProjects(in: context)

        #expect(try context.fetch(FetchDescriptor<Project>()).first?.status == .sent)
    }

    @Test func flagsProjectsBuiltOnlyFromSampleSessions() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let session = makeSession(daysAgo: 1, gym: nil, context: context)
        session.isSampleData = true
        let problem = SessionProblem(name: "Demo", colorGrade: .red, styles: [], fallCount: 2)
        session.problems = [problem]
        try context.save()

        try ProjectBackfill.backfillProjects(in: context)

        #expect(try context.fetch(FetchDescriptor<Project>()).first?.isSampleData == true)
    }

    @Test func secondRunCreatesNoDuplicates() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let session = makeSession(daysAgo: 1, gym: nil, context: context)
        let problem = SessionProblem(name: "Elektra", colorGrade: .red, styles: [], fallCount: 2)
        session.problems = [problem]
        try context.save()

        try ProjectBackfill.backfillProjects(in: context)
        try ProjectBackfill.backfillProjects(in: context)

        #expect(try context.fetchCount(FetchDescriptor<Project>()) == 1)
    }

    @Test func runIfNeededSkipsWorkOnceTheFlagIsSet() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let session = makeSession(daysAgo: 1, gym: nil, context: context)
        session.problems = [SessionProblem(name: "Elektra", colorGrade: .red, styles: [], fallCount: 2)]
        try context.save()
        let defaults = UserDefaults(suiteName: "ProjectBackfillTests")!
        defaults.removePersistentDomain(forName: "ProjectBackfillTests")

        ProjectBackfill.runIfNeeded(context: context, defaults: defaults)
        #expect(defaults.bool(forKey: ProjectBackfill.completedFlagKey))
        #expect(try context.fetchCount(FetchDescriptor<Project>()) == 1)

        let extraSession = makeSession(daysAgo: 0, gym: nil, context: context)
        extraSession.problems = [SessionProblem(name: "Later", colorGrade: .blue, styles: [], fallCount: 2)]
        try context.save()
        ProjectBackfill.runIfNeeded(context: context, defaults: defaults)

        #expect(try context.fetchCount(FetchDescriptor<Project>()) == 1)
    }
}
