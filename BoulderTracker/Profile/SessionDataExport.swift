import Foundation

/// Serializes logged sessions to a shareable JSON file.
enum SessionDataExport {
    struct ExportedProblem: Codable {
        let name: String
        let grade: String
        let styles: [String]
        let flashCount: Int
        let sendCount: Int
        let fallCount: Int
        let notes: String?
    }

    struct ExportedSession: Codable {
        let startTime: Date
        let endTime: Date?
        let gym: String?
        let shoe: String?
        let climbType: String
        let feeling: String?
        let notes: String?
        let partners: [String]
        let problems: [ExportedProblem]
    }

    static func jsonData(for sessions: [Session]) throws -> Data {
        let exported = sessions.map { session in
            ExportedSession(
                startTime: session.startTime,
                endTime: session.endTime,
                gym: session.gym?.name,
                shoe: session.shoe?.name,
                climbType: session.climbType.rawValue,
                feeling: session.feeling?.rawValue,
                notes: session.notes,
                partners: session.partners.map(\.name),
                problems: session.problems.map { problem in
                    ExportedProblem(
                        name: problem.name,
                        grade: problem.colorGrade.displayName,
                        styles: problem.styles.map(\.rawValue),
                        flashCount: problem.flashCount,
                        sendCount: problem.sendCount,
                        fallCount: problem.fallCount,
                        notes: problem.notes
                    )
                }
            )
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(exported)
    }

    static func writeJSONFile(for sessions: [Session]) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("boulder-tracker-export.json")
        try jsonData(for: sessions).write(to: url, options: .atomic)
        return url
    }
}
