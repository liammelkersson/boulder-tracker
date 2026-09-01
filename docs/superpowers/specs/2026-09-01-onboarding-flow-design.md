# Boulder Tracker Onboarding Flow — Design Spec

**Date:** 2026-09-01
**Status:** Approved design, pending implementation plan
**Platform:** iOS 26+, SwiftUI, SwiftData

## Purpose

Add a first-launch onboarding flow that makes Boulder Tracker feel intentional
from the first screen and collects the profile data needed for useful session
defaults. The flow sets up the climber's name, profile photo, climbing history,
preferred grade system, default gym, and optional shoes.

## Experience

Onboarding is a focused, full-screen wizard. Each screen asks for one decision,
supports back navigation, and shows progress. Required steps disable forward
navigation until their values are valid. Optional steps show a clear Skip action.

The sequence is:

1. Welcome
2. Name
3. Profile photo and climbing-since year
4. Default gym
5. Grade system
6. Shoes
7. Ready to climb

Name, a valid climbing-since year, default gym, and grade system are required.
Profile photo and shoes are optional.

## Visual direction

The welcome screen resembles a real indoor climbing wall. It uses a chalk-grey
surface with subtle panel seams, bolt holes, and the app's existing organic hold
shapes scattered across the full screen in grade colors. Holds have restrained
highlights and shadows for depth while leaving a calm central area for the app
mark, the line “Track every send,” and a black Get Started button.

Setup screens use the existing palette and faint wall texture on a warm off-white
background. Each has a strong centered prompt, a large focused control, a circular
forward button, a back button, and slim progress dots. Content moves horizontally
between steps. Welcome holds enter with a short staggered animation. Reduced Motion
removes nonessential movement.

The final screen reads “Ready to climb, <name>?” and summarizes the chosen gym and
shoes before completing setup.

## Architecture

`BoulderTrackerApp` gates its root content with a new
`AppPreferences.onboardingCompleteKey` value. An incomplete setup presents
`OnboardingFlowView`; a completed setup presents `RootTabView`.

`OnboardingFlowView` owns an `OnboardingDraft` for all entered values. Step views
bind to that draft and do not write to persistent storage. Navigation and validation
live in one coordinator so step ordering, required fields, and save behavior have a
single authoritative implementation.

The flow uses existing app boundaries:

- Name, climbing-since year, grade system, and completion state use `AppStorage` keys
  defined by `AppPreferences`.
- Gyms and shoes use the existing SwiftData `Gym` and `Shoe` models.
- Profile photos use the existing `PhotoStore`.
- Existing profile and preference screens remain the editing interface after setup.

## Gym behavior

The gym step lists existing seeded gyms and offers “Add another gym.” Selecting an
existing gym makes it the default. Adding a gym requires a nonempty trimmed name,
creates it during final save, and makes it the default. Every other gym is cleared
as default so there is exactly one default gym after onboarding.

## Shoes behavior

The shoe step accepts one pair during onboarding and can be skipped. A nonempty,
trimmed value creates one active `Shoe` during final save. Additional pairs and
retirement remain available from Profile.

## Persistence and failure handling

The flow holds edits in memory and persists them only when the final action succeeds.
The save order is:

1. Validate the full draft.
2. Resolve or create the default gym and clear other defaults.
3. Create the optional shoe.
4. Save the optional profile photo.
5. Save the SwiftData context.
6. Write profile and grade preferences.
7. Set the onboarding-complete flag last.

Setting completion last prevents navigation into the main app with an incomplete
profile. A save failure keeps the final screen visible, shows a concise error, and
offers Retry. Closing the app before completion restarts the flow without partial
profile records.

## Validation

- Name: trimmed value must not be empty.
- Climbing-since year: four digits, not in the future, and not earlier than 1900.
- Gym: one seeded selection or a nonempty trimmed custom name is required.
- Grade system: one supported `GradeSystem` is always selected.
- Photo: invalid or cancelled image selection behaves as no photo.
- Shoes: empty input is treated as skipped.

## Accessibility

- Controls support Dynamic Type without clipping or hiding required actions.
- All icon-only controls receive descriptive VoiceOver labels.
- Tap targets are at least 44 points.
- Text and holds preserve sufficient contrast in light and dark appearances.
- Reduce Motion replaces transitions with short fades and removes hold staggering.
- Keyboard focus advances naturally and dismisses before screen transitions.

## Testing

Unit tests cover:

- Required-field validation and whitespace trimming.
- Year boundary validation.
- Existing and custom gym resolution.
- Replacement of the previous default gym.
- Skipped and entered shoe paths.
- Completion state being written only after successful persistence.

UI-level smoke coverage verifies forward/back navigation, disabled required-step
actions, optional Skip actions, keyboard behavior, photo-picker cancellation, save
failure retry, and transition to the existing tab interface after completion.

## Out of scope

- Accounts, authentication, or cloud profile sync.
- Multiple shoes during onboarding.
- Gym search or remote gym directory.
- Re-running onboarding from Settings; profile screens already expose each value.
