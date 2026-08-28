import Foundation

enum AchievementEngine {
    private static let nightOwlHour = 21
    private static let marathonDuration: TimeInterval = 2 * 3600
    private static let sendMilestones = [10, 50, 100, 500]
    private static let sessionMilestones = [10, 50, 100]
    private static let weeklyStreakTarget = 5
    private static let threePerWeekWeeks = 4
    private static let blueFlashTarget = 10
    private static let styleVarietyTarget = 5
    private static let projectAttemptTarget = 100
    private static let globetrotterGymTarget = 3

    static func newlyUnlocked(sessions: [Session],
                              alreadyUnlocked: Set<String>) -> [AchievementDefinition] {
        definitions.filter { definition in
            !alreadyUnlocked.contains(definition.id) && definition.isSatisfied(sessions)
        }
    }

    static var definitions: [AchievementDefinition] {
        firstDefinitions + firstSendDefinitions + volumeDefinitions + streakDefinitions
            + skillDefinitions + funDefinitions
    }

    private static var firstDefinitions: [AchievementDefinition] {
        [
            AchievementDefinition(
                id: "first-session", title: "Off the Ground",
                detail: "Log your first session", symbolName: "figure.climbing"
            ) { !$0.isEmpty },
            AchievementDefinition(
                id: "first-flash", title: "First Flash",
                detail: "Top a problem first try", symbolName: "bolt.fill"
            ) { sessions in
                allAttempts(sessions).contains { $0.result == .flash }
            },
            AchievementDefinition(
                id: "first-photo", title: "Beta Archive",
                detail: "Add a photo to a problem", symbolName: "camera.fill"
            ) { sessions in
                allAttempts(sessions).contains { $0.photoFilename != nil }
            },
            AchievementDefinition(
                id: "first-partner-session", title: "Belay Buddies",
                detail: "Climb with a partner", symbolName: "person.2.fill"
            ) { sessions in
                sessions.contains { !$0.partners.isEmpty }
            },
        ]
    }

    private static var firstSendDefinitions: [AchievementDefinition] {
        ColorGrade.allCases.map { grade in
            AchievementDefinition(
                id: "first-send-\(grade.displayName.lowercased())",
                title: "\(grade.displayName) Breaker",
                detail: "Send your first \(grade.displayName.lowercased()) problem",
                symbolName: "checkmark.seal.fill"
            ) { sessions in
                allAttempts(sessions).contains { $0.colorGrade == grade && $0.result.countsAsSend }
            }
        }
    }

    private static var volumeDefinitions: [AchievementDefinition] {
        let sendItems = sendMilestones.map { milestone in
            AchievementDefinition(
                id: "sends-\(milestone)", title: "\(milestone) Sends",
                detail: "Send \(milestone) problems", symbolName: "flame.fill"
            ) { sessions in
                allAttempts(sessions).filter { $0.result.countsAsSend }.count >= milestone
            }
        }
        let sessionItems = sessionMilestones.map { milestone in
            AchievementDefinition(
                id: "sessions-\(milestone)", title: "\(milestone) Sessions",
                detail: "Log \(milestone) sessions", symbolName: "calendar.badge.checkmark"
            ) { sessions in
                sessions.count >= milestone
            }
        }
        return sendItems + sessionItems
    }

    private static var streakDefinitions: [AchievementDefinition] {
        [
            AchievementDefinition(
                id: "weekly-streak-5", title: "Regular",
                detail: "Climb every week for 5 weeks", symbolName: "repeat"
            ) { sessions in
                StatsAggregator.weeklyStreak(
                    of: sessions, calendar: .current, referenceDate: .now
                ) >= weeklyStreakTarget
            },
            AchievementDefinition(
                id: "three-per-week-4-weeks", title: "Dedicated",
                detail: "3 sessions a week, 4 weeks running", symbolName: "chart.line.uptrend.xyaxis"
            ) { sessions in
                hasConsecutiveWeeks(sessions, weeks: threePerWeekWeeks, sessionsPerWeek: 3)
            },
        ]
    }

    private static var skillDefinitions: [AchievementDefinition] {
        [
            AchievementDefinition(
                id: "flash-10-blues", title: "Blue Lightning",
                detail: "Flash \(blueFlashTarget) blue problems", symbolName: "bolt.badge.checkmark"
            ) { sessions in
                allAttempts(sessions)
                    .filter { $0.colorGrade == .blue && $0.result == .flash }
                    .count >= blueFlashTarget
            },
            AchievementDefinition(
                id: "five-styles", title: "All-Rounder",
                detail: "Send problems in \(styleVarietyTarget)+ styles", symbolName: "square.grid.3x3.fill"
            ) { sessions in
                let sentStyles = allAttempts(sessions)
                    .filter { $0.result.countsAsSend }
                    .flatMap(\.styles)
                return Set(sentStyles).count >= styleVarietyTarget
            },
            AchievementDefinition(
                id: "project-attempts-100", title: "Siege Tactics",
                detail: "\(projectAttemptTarget) attempts on projects", symbolName: "hammer.fill"
            ) { sessions in
                allAttempts(sessions)
                    .filter { $0.result == .project }
                    .reduce(0) { $0 + $1.attemptCount } >= projectAttemptTarget
            },
        ]
    }

    private static var funDefinitions: [AchievementDefinition] {
        [
            AchievementDefinition(
                id: "night-owl", title: "Night Owl",
                detail: "Finish a session after 21:00", symbolName: "moon.stars.fill"
            ) { sessions in
                sessions.contains { session in
                    guard let end = session.endTime else { return false }
                    return Calendar.current.component(.hour, from: end) >= nightOwlHour
                }
            },
            AchievementDefinition(
                id: "marathon", title: "Marathon",
                detail: "A session over 2 hours", symbolName: "stopwatch.fill"
            ) { sessions in
                sessions.contains { $0.duration >= marathonDuration }
            },
            AchievementDefinition(
                id: "globetrotter", title: "Globetrotter",
                detail: "Climb at \(globetrotterGymTarget) different gyms", symbolName: "globe.europe.africa.fill"
            ) { sessions in
                Set(sessions.compactMap { $0.gym?.name }).count >= globetrotterGymTarget
            },
        ]
    }

    private static func allAttempts(_ sessions: [Session]) -> [ProblemAttempt] {
        sessions.flatMap(\.attempts)
    }

    private static func hasConsecutiveWeeks(_ sessions: [Session], weeks: Int,
                                            sessionsPerWeek: Int) -> Bool {
        let calendar = Calendar.current
        let byWeek = Dictionary(grouping: sessions) { session in
            calendar.dateInterval(of: .weekOfYear, for: session.startTime)?.start ?? .distantPast
        }
        let qualifyingWeeks = byWeek.filter { $0.value.count >= sessionsPerWeek }.keys.sorted()
        var consecutive = 1
        for (previous, current) in zip(qualifyingWeeks, qualifyingWeeks.dropFirst()) {
            let gap = calendar.dateComponents([.weekOfYear], from: previous, to: current).weekOfYear ?? 0
            consecutive = gap == 1 ? consecutive + 1 : 1
            if consecutive >= weeks { return true }
        }
        return qualifyingWeeks.count >= weeks && consecutive >= weeks
    }
}
