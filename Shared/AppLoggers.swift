import OSLog

extension Logger {
    private static let subsystem = "com.liammelkersson.BoulderTracker"

    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let sync = Logger(subsystem: subsystem, category: "sync")
    static let health = Logger(subsystem: subsystem, category: "health")
}
