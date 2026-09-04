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
        let problems = allProblems(in: sessions)
        summary.problemCount = problems.count
        summary.sendCount = problems.reduce(0) { $0 + $1.sendCount + $1.flashCount }
        summary.flashCount = problems.reduce(0) { $0 + $1.flashCount }
        summary.attemptCount = problems.reduce(0) { $0 + $1.totalLogs }
        return summary
    }

    static func climbingDayCount(of sessions: [Session], calendar: Calendar) -> Int {
        Set(sessions.map { calendar.startOfDay(for: $0.startTime) }).count
    }

    static func sendCountPerGrade(of sessions: [Session]) -> [ColorGrade: Int] {
        var counts: [ColorGrade: Int] = [:]
        for problem in allProblems(in: sessions) where problem.wasSent {
            counts[problem.colorGrade, default: 0] += problem.sendCount + problem.flashCount
        }
        return counts
    }

    /// Distinct problems sent per grade. Unlike `sendCountPerGrade` a repeat
    /// ascent adds nothing: a pyramid counts climbs, not laps.
    static func sentProblemCountPerGrade(of sessions: [Session]) -> [ColorGrade: Int] {
        var counts: [ColorGrade: Int] = [:]
        for problem in allProblems(in: sessions) where problem.wasSent {
            counts[problem.colorGrade, default: 0] += 1
        }
        return counts
    }

    static func sendRatePerStyle(of sessions: [Session]) -> [RouteStyle: Double] {
        var totals: [RouteStyle: Int] = [:]
        var sends: [RouteStyle: Int] = [:]
        for problem in allProblems(in: sessions) {
            for style in problem.styles {
                totals[style, default: 0] += 1
                if problem.wasSent {
                    sends[style, default: 0] += 1
                }
            }
        }
        return totals.reduce(into: [:]) { rates, entry in
            rates[entry.key] = Double(sends[entry.key] ?? 0) / Double(entry.value)
        }
    }

    static func hardestSend(of sessions: [Session]) -> SessionProblem? {
        allProblems(in: sessions)
            .filter(\.wasSent)
            .max { $0.colorGrade < $1.colorGrade }
    }

    static func hardestFlash(of sessions: [Session]) -> SessionProblem? {
        allProblems(in: sessions)
            .filter(\.wasFlashed)
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

    static func proudestSend(of sessions: [Session]) -> SessionProblem? {
        allProblems(in: sessions)
            .filter(\.wasSent)
            .max { lhs, rhs in
                if lhs.colorGrade != rhs.colorGrade { return lhs.colorGrade < rhs.colorGrade }
                if lhs.totalLogs != rhs.totalLogs { return lhs.totalLogs < rhs.totalLogs }
                let lhsDate = lhs.session?.startTime ?? .distantPast
                let rhsDate = rhs.session?.startTime ?? .distantPast
                return lhsDate < rhsDate
            }
    }

    static func weeklyVolume(of sessions: [Session], calendar: Calendar) -> [WeeklyVolume] {
        sessionsByWeekStart(sessions, calendar: calendar)
            .map { weekStart, weekSessions in
                let problems = allProblems(in: weekSessions)
                return WeeklyVolume(
                    weekStart: weekStart,
                    problemCount: problems.count,
                    sendCount: problems.reduce(0) { $0 + $1.sendCount + $1.flashCount }
                )
            }
            .sorted { $0.weekStart < $1.weekStart }
    }

    static func hardestSendPerWeek(of sessions: [Session], calendar: Calendar) -> [WeeklyHardestSend] {
        sessionsByWeekStart(sessions, calendar: calendar)
            .compactMap { weekStart, weekSessions -> WeeklyHardestSend? in
                guard let hardest = hardestSend(of: weekSessions) else { return nil }
                return WeeklyHardestSend(weekStart: weekStart, grade: hardest.colorGrade)
            }
            .sorted { $0.weekStart < $1.weekStart }
    }

    private static func sessionsByWeekStart(
        _ sessions: [Session], calendar: Calendar
    ) -> [Date: [Session]] {
        Dictionary(grouping: sessions) { session in
            calendar.dateInterval(of: .weekOfYear, for: session.startTime)?.start
                ?? session.startTime
        }
    }

    private static func allProblems(in sessions: [Session]) -> [SessionProblem] {
        sessions.flatMap(\.problems)
    }
}
