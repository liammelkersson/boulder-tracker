import Foundation
import Testing
@testable import BoulderTracker

struct OnboardingDraftTests {
    @Test func nameRequiresNonWhitespaceText() {
        var draft = OnboardingDraft()
        draft.name = "   "

        #expect(draft.validationError(for: .name) == .missingName)

        draft.name = "  Liam  "
        #expect(draft.validationError(for: .name) == nil)
        #expect(draft.trimmedName == "Liam")
    }

    @Test func climbingYearRejectsOutOfRangeAndMalformedValues() {
        var draft = OnboardingDraft()
        let calendar = Calendar(identifier: .gregorian)
        let currentYear = calendar.component(.year, from: .now)

        for invalidYear in ["1899", String(currentYear + 1), "twenty", ""] {
            draft.climbingSinceYear = invalidYear
            #expect(
                draft.validationError(for: .profile, calendar: calendar) == .invalidClimbingYear,
                "Expected \(invalidYear) to be rejected"
            )
        }

        draft.climbingSinceYear = String(currentYear)
        #expect(draft.validationError(for: .profile, calendar: calendar) == nil)
    }

    @Test func gymRequiresExistingSelectionOrNamedCustomGym() {
        var draft = OnboardingDraft()
        #expect(draft.validationError(for: .gym) == .missingGym)

        draft.gymChoice = .custom
        draft.customGymName = "   "
        #expect(draft.validationError(for: .gym) == .missingGym)

        draft.customGymName = "  Bloc House  "
        #expect(draft.validationError(for: .gym) == nil)
        #expect(draft.trimmedCustomGymName == "Bloc House")
    }

    @Test func shoesAreOptionalAndTrimmed() {
        var draft = OnboardingDraft()
        #expect(draft.validationError(for: .shoes) == nil)
        #expect(draft.trimmedShoeName.isEmpty)

        draft.shoeName = "  Scarpa Drago  "
        #expect(draft.trimmedShoeName == "Scarpa Drago")
    }

    @Test func onlyRequiredStepsCanBlockForwardNavigation() {
        var draft = OnboardingDraft()
        draft.name = "Liam"
        draft.climbingSinceYear = "2024"

        #expect(draft.validationError(for: .welcome) == nil)
        #expect(draft.validationError(for: .gradeSystem) == nil)
        #expect(draft.validationError(for: .shoes) == nil)
        #expect(draft.validationError(for: .ready) == nil)
    }
}
