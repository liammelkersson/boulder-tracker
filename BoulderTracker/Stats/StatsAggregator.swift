import Foundation

enum StatsAggregator {
    static func sessions(_ sessions: [Session], in interval: DateInterval?) -> [Session] {
        guard let interval else { return sessions }
        return sessions.filter { interval.contains($0.startTime) }
    }

    static func summary(of sessions: [Session]) -> StatsSummary {
        var summary = StatsSummary()
        summary.sessionCount = sessions.count
        summary.totalDuration = sessions.reduce(0) { $0 + $1.duration }
        let attempts = allAttempts(in: sessions)
        summary.problemCount = attempts.count
        summary.sendCount = attempts.filter { $0.result.countsAsSend }.count
        summary.flashCount = attempts.filter { $0.result == .flash }.count
        summary.attemptCount = attempts.reduce(0) { $0 + $1.attemptCount }
        return summary
    }

    static func climbingDayCount(of sessions: [Session], calendar: Calendar) -> Int {
        Set(sessions.map { calendar.startOfDay(for: $0.startTime) }).count
    }

    static func sendCountPerGrade(of sessions: [Session]) -> [ColorGrade: Int] {
        let sends = allAttempts(in: sessions).filter { $0.result.countsAsSend }
        return Dictionary(grouping: sends, by: \.colorGrade).mapValues(\.count)
    }

    static func sendRatePerStyle(of sessions: [Session]) -> [RouteStyle: Double] {
        var totals: [RouteStyle: Int] = [:]
        var sends: [RouteStyle: Int] = [:]
        for attempt in allAttempts(in: sessions) {
            for style in attempt.styles {
                totals[style, default: 0] += 1
                if attempt.result.countsAsSend {
                    sends[style, default: 0] += 1
                }
            }
        }
        return totals.reduce(into: [:]) { rates, entry in
            rates[entry.key] = Double(sends[entry.key] ?? 0) / Double(entry.value)
        }
    }

    static func hardestSend(of sessions: [Session]) -> ProblemAttempt? {
        allAttempts(in: sessions)
            .filter { $0.result.countsAsSend }
            .max { $0.colorGrade < $1.colorGrade }
    }

    static func hardestFlash(of sessions: [Session]) -> ProblemAttempt? {
        allAttempts(in: sessions)
            .filter { $0.result == .flash }
            .max { $0.colorGrade < $1.colorGrade }
    }

    static func weeklyStreak(of sessions: [Session], calendar: Calendar, referenceDate: Date) -> Int {
        let sessionWeeks = Set(sessions.compactMap { session in
            calendar.dateInterval(of: .weekOfYear, for: session.startTime)?.start
        })
        var streak = 0
        var cursor = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start
        while let week = cursor, sessionWeeks.contains(week) {
            streak += 1
            cursor = calendar.date(byAdding: .weekOfYear, value: -1, to: week)
        }
        return streak
    }

    static func proudestSend(of sessions: [Session]) -> ProblemAttempt? {
        allAttempts(in: sessions)
            .filter { $0.result.countsAsSend }
            .max { lhs, rhs in
                if lhs.colorGrade != rhs.colorGrade { return lhs.colorGrade < rhs.colorGrade }
                if lhs.attemptCount != rhs.attemptCount { return lhs.attemptCount < rhs.attemptCount }
                let lhsDate = lhs.session?.startTime ?? .distantPast
                let rhsDate = rhs.session?.startTime ?? .distantPast
                return lhsDate < rhsDate
            }
    }

    private static func allAttempts(in sessions: [Session]) -> [ProblemAttempt] {
        sessions.flatMap(\.attempts)
    }
}
