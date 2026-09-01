import Foundation
import SwiftData

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case name
    case profile
    case gym
    case gradeSystem
    case shoes
    case ready
}

enum OnboardingValidationError: Error, Equatable {
    case missingName
    case invalidClimbingYear
    case missingGym
}

enum OnboardingGymChoice: Equatable {
    case existing(PersistentIdentifier)
    case custom
}

struct OnboardingDraft {
    var name = ""
    var climbingSinceYear = String(Calendar.current.component(.year, from: .now))
    var avatarData: Data?
    var gymChoice: OnboardingGymChoice?
    var customGymName = ""
    var gradeSystem = GradeSystem.default
    var shoeName = ""

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedCustomGymName: String {
        customGymName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    var trimmedShoeName: String { shoeName.trimmingCharacters(in: .whitespacesAndNewlines) }

    func validationError(
        for step: OnboardingStep,
        calendar: Calendar = .current
    ) -> OnboardingValidationError? {
        switch step {
        case .name:
            return trimmedName.isEmpty ? .missingName : nil
        case .profile:
            guard climbingSinceYear.count == 4,
                  let year = Int(climbingSinceYear),
                  1900...calendar.component(.year, from: .now) ~= year else {
                return .invalidClimbingYear
            }
            return nil
        case .gym:
            switch gymChoice {
            case .existing:
                return nil
            case .custom where !trimmedCustomGymName.isEmpty:
                return nil
            case .custom, nil:
                return .missingGym
            }
        case .welcome, .gradeSystem, .shoes, .ready:
            return nil
        }
    }
}
