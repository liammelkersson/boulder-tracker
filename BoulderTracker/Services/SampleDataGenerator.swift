import Foundation
import SwiftData

/// Inserts and removes flagged demo sessions so every stats chart has data
/// to show without months of real logging.
enum SampleDataGenerator {
    private static let sessionCount = 20
    private static let periodDays = 90
    private static let secondsPerDay: TimeInterval = 24 * 3600
    private static let sampleShoeName = "Demo Shoe — Drago"

    private static let problemNames = [
        "Elektra", "Moonwalk", "The Roof", "Slab Ritual", "Crimp City",
        "Big Air", "Pinch Point", "Compression Test", "Traverse Line", "Pocket Rocket",
    ]
    private static let styleRotation: [[RouteStyle]] = [
        [.crimp, .vertical], [.dyno, .coordination], [.sloper, .compression],
        [.jug, .overhang], [.slab, .mantle], [.pinch, .arete],
        [.pocket, .roof], [.dyno], [.crimp, .overhang], [.traverse],
    ]
    private static let gradeRotation: [ColorGrade] = [
        .green, .blue, .blue, .red, .red, .black, .green, .blue, .red, .yellow,
    ]

    static func insertSampleData(into context: ModelContext, referenceDate: Date) throws {
        let shoe = Shoe(name: sampleShoeName)
        shoe.isSampleData = true
        context.insert(shoe)
        let gym = try? context.fetch(FetchDescriptor<Gym>()).first
        for sessionIndex in 0..<sessionCount {
            let session = makeSampleSession(
                sessionIndex: sessionIndex, gym: gym, shoe: shoe, referenceDate: referenceDate
            )
            context.insert(session)
        }
        try context.save()
    }

    static func removeSampleData(from context: ModelContext) throws {
        // Per-object deletes: batch delete rejects the mandatory nullify
        // inverse between Session.shoe and Shoe.sessions.
        let sampleSessions = try context.fetch(
            FetchDescriptor<Session>(predicate: #Predicate { $0.isSampleData })
        )
        for session in sampleSessions {
            context.delete(session)
        }
        let sampleShoes = try context.fetch(
            FetchDescriptor<Shoe>(predicate: #Predicate { $0.isSampleData })
        )
        for shoe in sampleShoes {
            context.delete(shoe)
        }
        try context.save()
    }

    static func sampleDataExists(in context: ModelContext) -> Bool {
        var descriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.isSampleData })
        descriptor.fetchLimit = 1
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }

    private static func makeSampleSession(
        sessionIndex: Int, gym: Gym?, shoe: Shoe, referenceDate: Date
    ) -> Session {
        let daysBack = sessionIndex * periodDays / sessionCount
        let startHourOffset = TimeInterval(17 + sessionIndex % 3) * 3600
        let dayStart = referenceDate.addingTimeInterval(-TimeInterval(daysBack + 1) * secondsPerDay)
        let start = min(dayStart.addingTimeInterval(startHourOffset), referenceDate)
        let durationMinutes = 75 + (sessionIndex % 4) * 20

        let session = Session(startTime: start, gym: gym, partners: [])
        session.endTime = start.addingTimeInterval(TimeInterval(durationMinutes * 60))
        session.feeling = SessionFeeling.allCases[sessionIndex % SessionFeeling.allCases.count]
        session.isSampleData = true
        session.shoe = shoe
        session.problems = makeSampleProblems(sessionIndex: sessionIndex)
        return session
    }

    private static func makeSampleProblems(sessionIndex: Int) -> [SessionProblem] {
        let problemCount = 3 + sessionIndex % 4
        return (0..<problemCount).map { problemIndex in
            let rotationIndex = (sessionIndex + problemIndex) % problemNames.count
            // Recent sessions trend one grade tier harder so progression charts climb.
            let baseGrade = gradeRotation[rotationIndex]
            let isRecent = sessionIndex < sessionCount / 3
            let grade = isRecent && baseGrade == .blue ? .red : baseGrade
            let problem = SessionProblem(
                name: problemNames[rotationIndex],
                colorGrade: grade,
                styles: styleRotation[rotationIndex],
                flashCount: problemIndex % 3 == 0 ? 1 : 0,
                sendCount: problemIndex % 3 == 1 ? 1 : 0,
                fallCount: (sessionIndex + problemIndex) % 4
            )
            return problem
        }
    }
}
