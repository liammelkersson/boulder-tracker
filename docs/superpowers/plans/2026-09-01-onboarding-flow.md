# Boulder Tracker Onboarding Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Build a first-launch SwiftUI wizard that collects required climber and gym details, optional photo and shoes, then enters the existing app.

**Architecture:** A pure OnboardingDraft owns step state and validation. OnboardingSaver injects persistence dependencies and commits existing SwiftData models, photo storage, and preferences in a completion-last sequence. Focused step views compose inside one flow coordinator, while the app root gates onboarding with AppStorage.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, PhotosUI, Swift Testing, XCUITest, iOS 26+

**Spec:** docs/superpowers/specs/2026-09-01-onboarding-flow-design.md

## Global Constraints

- Deployment target remains iOS 26.0.
- Use no third-party dependencies.
- Name, climbing-since year, gym, and grade system are required.
- Profile photo and one shoe entry are optional.
- Reuse Gym, Shoe, GradeSystem, PhotoStore, HoldBlobShape, WallTexture, and theme tokens.
- Set pref.onboardingComplete only after every earlier persistence operation succeeds.
- Preserve existing user changes in the dirty worktree; stage only files listed by each task.

## File Structure

- BoulderTracker/Onboarding/OnboardingDraft.swift: steps, draft values, trimming, and validation.
- BoulderTracker/Onboarding/OnboardingSaver.swift: persistence orchestration and rollback.
- BoulderTracker/Onboarding/OnboardingWallView.swift: wall surface, bolts, seams, and holds.
- BoulderTracker/Onboarding/OnboardingWelcomeView.swift: first-screen content and entrance animation.
- BoulderTracker/Onboarding/OnboardingProfileSteps.swift: name, photo, and climbing-year controls.
- BoulderTracker/Onboarding/OnboardingClimbingSteps.swift: gym, grade-system, and shoe controls.
- BoulderTracker/Onboarding/OnboardingReadyView.swift: summary and completion action.
- BoulderTracker/Onboarding/OnboardingFlowView.swift: navigation, photo loading, and save errors.
- BoulderTracker/App/AppPreferences.swift: onboarding completion key.
- BoulderTracker/App/BoulderTrackerApp.swift: root gate.
- BoulderTrackerTests/OnboardingDraftTests.swift: validation behavior.
- BoulderTrackerTests/OnboardingSaverTests.swift: persistence behavior.
- BoulderTrackerUITests/OnboardingFlowUITests.swift: first-run navigation smoke coverage.
- project.yml and BoulderTracker.xcodeproj/project.pbxproj: UI-test target and source references.

---

### Task 1: Draft model and validation

**Files:**
- Create: BoulderTracker/Onboarding/OnboardingDraft.swift
- Test: BoulderTrackerTests/OnboardingDraftTests.swift

**Interfaces:**
- Produces OnboardingStep, OnboardingGymChoice, OnboardingValidationError, and OnboardingDraft.
- Produces OnboardingDraft.validationError(for:calendar:) -> OnboardingValidationError?.
- Produces trimmedName, trimmedCustomGymName, and trimmedShoeName.

- [ ] **Step 1: Write failing validation tests**

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

        @Test func climbingYearRejectsFutureValues() {
            var draft = OnboardingDraft()
            let calendar = Calendar(identifier: .gregorian)
            let year = calendar.component(.year, from: .now)
            draft.climbingSinceYear = String(year + 1)
            #expect(draft.validationError(for: .profile, calendar: calendar) == .invalidClimbingYear)
            draft.climbingSinceYear = String(year)
            #expect(draft.validationError(for: .profile, calendar: calendar) == nil)
        }

        @Test func gymRequiresASelection() {
            var draft = OnboardingDraft()
            #expect(draft.validationError(for: .gym) == .missingGym)
            draft.gymChoice = .custom
            draft.customGymName = "  Bloc House  "
            #expect(draft.validationError(for: .gym) == nil)
            #expect(draft.trimmedCustomGymName == "Bloc House")
        }

        @Test func shoesAreOptionalAndTrimmed() {
            var draft = OnboardingDraft()
            #expect(draft.validationError(for: .shoes) == nil)
            draft.shoeName = "  Scarpa Drago  "
            #expect(draft.trimmedShoeName == "Scarpa Drago")
        }
    }

- [ ] **Step 2: Run the focused tests**

    xcodebuild test -project BoulderTracker.xcodeproj -scheme BoulderTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BoulderTrackerTests/OnboardingDraftTests

Expected: compile failure because OnboardingDraft does not exist.

- [ ] **Step 3: Implement minimal pure types**

    enum OnboardingStep: Int, CaseIterable {
        case welcome, name, profile, gym, gradeSystem, shoes, ready
    }

    enum OnboardingValidationError: Error, Equatable {
        case missingName, invalidClimbingYear, missingGym
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
    }

Validation trims whitespace and enforces year range 1900 through current calendar year.

- [ ] **Step 4: Run focused tests and confirm PASS.**

- [ ] **Step 5: Commit**

    git add BoulderTracker/Onboarding/OnboardingDraft.swift BoulderTrackerTests/OnboardingDraftTests.swift
    git commit -m "feat: add onboarding draft validation"

---

### Task 2: Persistence transaction

**Files:**
- Create: BoulderTracker/Onboarding/OnboardingSaver.swift
- Modify: BoulderTracker/App/AppPreferences.swift
- Test: BoulderTrackerTests/OnboardingSaverTests.swift

**Interfaces:**
- Consumes validated OnboardingDraft.
- Produces @MainActor OnboardingSaver.save(_:gyms:context:) throws.
- Produces OnboardingSaving protocol and OnboardingSaver.live.
- Produces AppPreferences.onboardingCompleteKey = pref.onboardingComplete.

- [ ] **Step 1: Write failing saver tests**

Use isolated UserDefaults(suiteName:), an in-memory ModelContainer, and injected photo closures. Cover existing gym, custom gym, optional shoe, preference writes, and failing photo storage.

    try saver.save(draft, gyms: gyms, context: context)
    #expect(selectedGym.isDefault)
    #expect(!previousDefault.isDefault)
    #expect(defaults.string(forKey: AppPreferences.profileNameKey) == "Liam")
    #expect(defaults.string(forKey: AppPreferences.gradeSystemKey) == GradeSystem.vScale.rawValue)
    #expect(defaults.bool(forKey: AppPreferences.onboardingCompleteKey))

    #expect(throws: Error.self) {
        try failingSaver.save(photoDraft, gyms: gyms, context: context)
    }
    #expect(!defaults.bool(forKey: AppPreferences.onboardingCompleteKey))
    #expect(try context.fetch(FetchDescriptor<Shoe>()).isEmpty)

- [ ] **Step 2: Run only OnboardingSaverTests and confirm compile failure.**

- [ ] **Step 3: Implement saver with injected boundaries**

Initializer dependencies: UserDefaults, savePhoto(Data) throws -> String, and deletePhoto(String) throws -> Void. Resolve existing gym by PersistentIdentifier or insert custom gym. Snapshot old default flags. Optionally insert one Shoe. Save photo before context.save(). After the context succeeds, write profile values and completion last. On thrown work, delete inserted models, restore default flags, remove any newly written photo, rollback the context, and keep completion false.

- [ ] **Step 4: Run OnboardingSaverTests and all OnboardingDraftTests; confirm PASS.**

- [ ] **Step 5: Commit**

    git add BoulderTracker/App/AppPreferences.swift BoulderTracker/Onboarding/OnboardingSaver.swift BoulderTrackerTests/OnboardingSaverTests.swift
    git commit -m "feat: persist onboarding profile setup"

---

### Task 3: Welcome wall and wizard shell

**Files:**
- Create: BoulderTracker/Onboarding/OnboardingWallView.swift
- Create: BoulderTracker/Onboarding/OnboardingWelcomeView.swift
- Create: BoulderTracker/Onboarding/OnboardingFlowView.swift

**Interfaces:**
- Consumes OnboardingStep and OnboardingDraft.
- Produces OnboardingWallView, OnboardingWelcomeView(onStart:), and OnboardingFlowView(saver:).
- Provides accessibility identifiers onboarding.getStarted, onboarding.back, onboarding.next, onboarding.skip, and onboarding.progress.

- [ ] **Step 1: Add flow shell referencing not-yet-created wall and welcome views.**

Use @State step and draft, @Environment accessibilityReduceMotion, horizontal transitions, and injected saver. Setup screens share back button, progress capsules, forward button, and Skip placement.

- [ ] **Step 2: Build and confirm expected missing-type failures.**

    xcodebuild build -project BoulderTracker.xcodeproj -scheme BoulderTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

- [ ] **Step 3: Implement deterministic wall visual.**

Canvas draws chalk-grey panels, seams, and bolt holes. Overlay 18 fixed HoldBlobShape instances in grade colors with highlight gradients, bottom shadows, rotations, and center bolts. Keep central copy area calm. Reduced Motion disables staggered hold scaling and opacity.

- [ ] **Step 4: Implement welcome and shared chrome.**

Welcome contains app title, “Track every send,” and black Get Started capsule. Setup shell has 44-point controls, VoiceOver labels, progress, keyboard-safe layout, step announcements, disabled invalid forward actions, and fade-only reduced-motion transitions.

- [ ] **Step 5: Build app target and confirm PASS.**

- [ ] **Step 6: Commit**

    git add BoulderTracker/Onboarding/OnboardingWallView.swift BoulderTracker/Onboarding/OnboardingWelcomeView.swift BoulderTracker/Onboarding/OnboardingFlowView.swift
    git commit -m "feat: add onboarding wall and flow shell"

---

### Task 4: Profile, climbing, and ready steps

**Files:**
- Create: BoulderTracker/Onboarding/OnboardingProfileSteps.swift
- Create: BoulderTracker/Onboarding/OnboardingClimbingSteps.swift
- Create: BoulderTracker/Onboarding/OnboardingReadyView.swift
- Modify: BoulderTracker/Onboarding/OnboardingFlowView.swift

**Interfaces:**
- Produces focused views bound to OnboardingDraft.
- Consumes queried [Gym] and OnboardingSaving.

- [ ] **Step 1: Implement name and profile views.**

Name uses a large centered TextField with name content type and submit navigation. Profile uses PhotosPicker, circular preview, removable selection, and four-digit number-pad year. Cancellation preserves draft state.

- [ ] **Step 2: Implement gym, grade, and shoe views.**

Gym shows existing seeded gyms as selectable cards and Add another gym custom mode. Grade renders every GradeSystem case with examples. Shoe is one optional focused field with visible Skip.

- [ ] **Step 3: Implement ready summary and retry behavior.**

Show “Ready to climb, <name>?”, resolved gym label, optional shoe, and Start climbing. Disable navigation while saving. Catch saver errors, remain on ready, show “Couldn’t finish setup,” and allow Retry with draft preserved.

- [ ] **Step 4: Build and run full unit suite.**

    xcodebuild test -project BoulderTracker.xcodeproj -scheme BoulderTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

Expected: TEST SUCCEEDED.

- [ ] **Step 5: Commit**

    git add BoulderTracker/Onboarding
    git commit -m "feat: add onboarding setup steps"

---

### Task 5: Root gate and UI smoke coverage

**Files:**
- Modify: BoulderTracker/App/BoulderTrackerApp.swift
- Modify: project.yml
- Modify: BoulderTracker.xcodeproj/project.pbxproj
- Create: BoulderTrackerUITests/OnboardingFlowUITests.swift

**Interfaces:**
- Consumes AppPreferences.onboardingCompleteKey and OnboardingFlowView.
- Produces first-launch root switch and deterministic UI-test reset argument.

- [ ] **Step 1: Add failing XCUITest coverage.**

Launch with -uiTestingResetOnboarding YES. Test Get Started, required name validation, forward/back, photo Skip, seeded gym choice, grade selection, shoe Skip, completion, and visible existing TabView.

- [ ] **Step 2: Add AppRootView gate.**

AppRootView uses @AppStorage(onboardingCompleteKey), showing OnboardingFlowView when false and RootTabView when true. Both receive the sync coordinator. During UI testing, reset the completion preference before root rendering.

- [ ] **Step 3: Add UI-test target and regenerate.**

Add application.ui-testing BoulderTrackerUITests target depending on BoulderTracker, include it in scheme tests, then run:

    xcodegen generate

Verify Icon Composer remains folder.iconcomposer.icon after post-generation patch.

- [ ] **Step 4: Run full phone test suite and confirm PASS.**

    xcodebuild test -project BoulderTracker.xcodeproj -scheme BoulderTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

- [ ] **Step 5: Manually verify system-owned behavior.**

Cancel PhotosPicker; confirm profile remains usable. Check Larger Accessibility Sizes and Reduce Motion; confirm content stays reachable, controls stay 44 points, and hold staggering disappears.

- [ ] **Step 6: Commit**

    git add BoulderTracker/App/BoulderTrackerApp.swift project.yml BoulderTracker.xcodeproj/project.pbxproj BoulderTrackerUITests/OnboardingFlowUITests.swift
    git commit -m "feat: show onboarding on first launch"

---

### Task 6: Final verification

**Files:**
- Modify only files requiring fixes discovered during verification.

**Interfaces:**
- Produces verified onboarding matching approved spec.

- [ ] **Step 1: Check diff hygiene.**

    git diff --check
    git status --short

Confirm unrelated pre-existing changes remain unstaged and untouched.

- [ ] **Step 2: Run full phone tests.**

    xcodebuild test -project BoulderTracker.xcodeproj -scheme BoulderTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

Expected: TEST SUCCEEDED.

- [ ] **Step 3: Run watch regression build.**

    xcodebuild build -project BoulderTracker.xcodeproj -scheme BoulderTrackerWatch -destination 'generic/platform=watchOS Simulator'

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Review spec coverage.**

Verify required and optional fields, seeded and custom gym paths, completion-last behavior, wall visuals, retry state, accessibility, and existing profile editing. Record any simulator-only limitation in handoff.
