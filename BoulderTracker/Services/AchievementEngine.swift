import Foundation

enum AchievementEngine {
    private static let nightOwlHour = 21
    private static let nightOwlTarget = 5
    private static let marathonDuration: TimeInterval = 3 * 3600
    private static let sendMilestones = [10, 50, 100, 500]
    private static let sessionMilestones = [10, 50, 100]
    private static let weeklyStreakTarget = 5
    private static let threePerWeekWeeks = 4
    private static let blueFlashTarget = 10
    private static let styleVarietyTarget = 5
    private static let projectAttemptTarget = 100
    private static let globetrotterGymTarget = 3
    private static let outdoorSessionTarget = 5
    private static let firstSendGrades: [ColorGrade] = [.green, .blue, .red, .black, .white]

    static func newlyUnlocked(sessions: [Session],
                              alreadyUnlocked: Set<String>) -> [AchievementDefinition] {
        definitions.filter { definition in
            !alreadyUnlocked.contains(definition.id) && definition.isSatisfied(by: sessions)
        }
    }

    static var definitions: [AchievementDefinition] {
        firstDefinitions + firstSendDefinitions + volumeDefinitions + streakDefinitions
            + skillDefinitions + funDefinitions + outdoorDefinitions
    }

    private static var firstDefinitions: [AchievementDefinition] {
        [
            AchievementDefinition(
                id: "first-session", title: "Off the Ground",
                detail: "Log your first session", symbolName: "figure.climbing", target: 1
            ) { $0.count },
            AchievementDefinition(
                id: "first-flash", title: "First Flash",
                detail: "Top a problem first try", symbolName: "bolt.fill", target: 1
            ) { sessions in
                allProblems(sessions).count(where: \.wasFlashed)
            },
            AchievementDefinition(
                id: "first-photo", title: "Beta Archive",
                detail: "Add a photo to a problem", symbolName: "camera.fill", target: 1
            ) { sessions in
                allProblems(sessions).count { $0.photoFilename != nil }
            },
            AchievementDefinition(
                id: "first-partner-session", title: "Belay Buddies",
                detail: "Climb with a partner", symbolName: "person.2.fill", target: 1
            ) { sessions in
                sessions.count { !$0.partners.isEmpty }
            },
        ]
    }

    private static var firstSendDefinitions: [AchievementDefinition] {
        firstSendGrades.map { grade in
            AchievementDefinition(
                id: "first-send-\(grade.displayName.lowercased())",
                title: "First \(grade.displayName)",
                detail: "Send your first \(grade.displayName.lowercased()) problem",
                symbolName: "checkmark.seal.fill", target: 1
            ) { sessions in
                allProblems(sessions).count { $0.colorGrade == grade && $0.wasSent }
            }
        }
    }

    private static var volumeDefinitions: [AchievementDefinition] {
        let sendItems = sendMilestones.map { milestone in
            AchievementDefinition(
                id: "sends-\(milestone)", title: "\(milestone) Sends",
                detail: "Send \(milestone) problems", symbolName: "flame.fill", target: milestone
            ) { sessions in
                allProblems(sessions).count(where: \.wasSent)
            }
        }
        let sessionItems = sessionMilestones.map { milestone in
            AchievementDefinition(
                id: "sessions-\(milestone)", title: "\(milestone) Sessions",
                detail: "Log \(milestone) sessions", symbolName: "calendar.badge.checkmark",
                target: milestone
            ) { sessions in
                sessions.count
            }
        }
        return sendItems + sessionItems
    }

    private static var streakDefinitions: [AchievementDefinition] {
        [
            AchievementDefinition(
                id: "weekly-streak-5", title: "Regular",
                detail: "Climb every week for \(weeklyStreakTarget) weeks", symbolName: "repeat",
                target: weeklyStreakTarget
            ) { sessions in
                StatsAggregator.weeklyStreak(of: sessions, calendar: .current, referenceDate: .now)
            },
            AchievementDefinition(
                id: "three-per-week-4-weeks", title: "Dedicated",
                detail: "3 sessions a week, \(threePerWeekWeeks) weeks running",
                symbolName: "chart.line.uptrend.xyaxis", target: threePerWeekWeeks
            ) { sessions in
                longestConsecutiveWeekRun(sessions, sessionsPerWeek: 3)
            },
        ]
    }

    private static var skillDefinitions: [AchievementDefinition] {
        [
            AchievementDefinition(
                id: "flash-10-blues", title: "Blue Lightning",
                detail: "Flash \(blueFlashTarget) blue problems", symbolName: "bolt.badge.checkmark",
                target: blueFlashTarget
            ) { sessions in
                allProblems(sessions).count { $0.colorGrade == .blue && $0.wasFlashed }
            },
            AchievementDefinition(
                id: "five-styles", title: "All-Rounder",
                detail: "Send problems in \(styleVarietyTarget)+ styles",
                symbolName: "square.grid.3x3.fill", target: styleVarietyTarget
            ) { sessions in
                let sentStyles = allProblems(sessions).filter(\.wasSent).flatMap(\.styles)
                return Set(sentStyles).count
            },
            AchievementDefinition(
                id: "project-attempts-100", title: "Siege Tactics",
                detail: "\(projectAttemptTarget) falls logged on projects", symbolName: "hammer.fill",
                target: projectAttemptTarget
            ) { sessions in
                allProblems(sessions).reduce(0) { $0 + $1.fallCount }
            },
        ]
    }

    private static var funDefinitions: [AchievementDefinition] {
        [
            AchievementDefinition(
                id: "night-owl", title: "Night Owl",
                detail: "Finish \(nightOwlTarget) sessions after \(nightOwlHour):00",
                symbolName: "moon.stars.fill", target: nightOwlTarget
            ) { sessions in
                sessions.count { session in
                    guard let end = session.endTime else { return false }
                    return Calendar.current.component(.hour, from: end) >= nightOwlHour
                }
            },
            AchievementDefinition(
                id: "marathon", title: "Marathon",
                detail: "A session over 3 hours", symbolName: "stopwatch.fill", target: 1
            ) { sessions in
                sessions.count { $0.duration >= marathonDuration }
            },
            AchievementDefinition(
                id: "globetrotter", title: "Globetrotter",
                detail: "Climb at \(globetrotterGymTarget) different gyms",
                symbolName: "globe.europe.africa.fill", target: globetrotterGymTarget
            ) { sessions in
                Set(sessions.compactMap { $0.gym?.name }).count
            },
        ]
    }

    private static var outdoorDefinitions: [AchievementDefinition] {
        [
            AchievementDefinition(
                id: "outdoor-first", title: "Rock On",
                detail: "Log your first outdoor session", symbolName: "mountain.2.fill",
                target: 1, iconStyle: .outdoorRock, currentCount: outdoorSessionCount
            ),
            AchievementDefinition(
                id: "outdoor-\(outdoorSessionTarget)", title: "Weathered",
                detail: "Log \(outdoorSessionTarget) outdoor sessions",
                symbolName: "mountain.2.fill",
                target: outdoorSessionTarget, iconStyle: .outdoorRock,
                currentCount: outdoorSessionCount
            ),
        ]
    }

    private static func outdoorSessionCount(in sessions: [Session]) -> Int {
        sessions.count { $0.climbType == .boulderingOutdoor }
    }

    private static func allProblems(_ sessions: [Session]) -> [SessionProblem] {
        sessions.flatMap(\.problems)
    }

    private static func longestConsecutiveWeekRun(_ sessions: [Session],
                                                  sessionsPerWeek: Int) -> Int {
        let calendar = Calendar.current
        let byWeek = Dictionary(grouping: sessions) { session in
            calendar.dateInterval(of: .weekOfYear, for: session.startTime)?.start ?? .distantPast
        }
        let qualifyingWeeks = byWeek.filter { $0.value.count >= sessionsPerWeek }.keys.sorted()
        guard !qualifyingWeeks.isEmpty else { return 0 }
        var longest = 1
        var consecutive = 1
        for (previous, current) in zip(qualifyingWeeks, qualifyingWeeks.dropFirst()) {
            let gap = calendar.dateComponents([.weekOfYear], from: previous, to: current).weekOfYear ?? 0
            consecutive = gap == 1 ? consecutive + 1 : 1
            longest = max(longest, consecutive)
        }
        return longest
    }
}
