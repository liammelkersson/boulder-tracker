# Hardening & Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land 14 improvement items from the 2026-09-01 audit: crash-guard sweep, shoes completion, repo hygiene, sync correctness (dual live session, catalog push, delete event, outbox robustness), logging, DI + tests for sync coordinators, CloudKit backup, entity deletion, accessibility, and misc polish.

**Architecture:** All work stays inside existing seams: `SyncLinking` for transport, `SessionSyncInbox`/`SessionSyncOutbox` for events, `PersistentModelInvalidation` for delete guards. New pieces: `Logger` extensions, a `sessionDeleted` sync event, a scaled-font modifier, CloudKit-first container fallback.

**Tech Stack:** SwiftUI, SwiftData (+CloudKit), WatchConnectivity, HealthKit, Swift Testing (`@Test`/`#expect`), XcodeGen.

**Spec:** The audit findings in this conversation; design spec at `docs/superpowers/specs/2026-08-28-boulder-tracker-design.md`.

## Global Constraints

- Swift 6.0, iOS 26 / watchOS 26 deployment targets (`project.yml`).
- Commit convention: plain conventional commits (`feat:`, `fix:`, `refactor:`, `chore:`), no Co-Authored-By line.
- Refactors commit separately from behavior changes.
- Tests: Swift Testing framework, in-memory `ModelContainer`, run via `xcodebuild test -scheme BoulderTracker -destination 'platform=iOS Simulator,id=4F06D682-66C1-4FD0-A29E-B7615C3E960F'`.
- XcodeGen owns the project: after adding files, run `xcodegen generate` (postGenCommand patches the icon type).
- No `try?` swallows on persistence paths touched by this plan — log via `Logger`.

---

### Task 0: Snapshot existing branch work

Existing uncommitted grade-system/shoes/sample-data/charts work must be committed before new edits so this plan's changes stay reviewable.

- [ ] Delete stray junk first so it never enters history: `Icon\r` (0-byte), `boulder-tracker-iOS-Default-1024x1024@1x.png`, `boulder-tracker-iOS-Default-256x256@1x.png` (repo root).
- [ ] Append to `.gitignore`: `Icon?` and `/boulder-tracker-iOS-Default-*.png`.
- [ ] `git add -A && git commit -m "feat: shoes, sample data, stats charts, and grade-system cleanup (wip)"` then `git commit` the gitignore change separately as `chore: ignore Finder icon artifacts and icon-export strays`.
- [ ] Verify: `git status` clean; `xcodebuild build` succeeds.

### Task 1 (#14a): Make PhoneSyncCoordinator and WatchSyncCoordinator injectable (refactor only)

**Files:** Modify `BoulderTracker/Services/PhoneSyncCoordinator.swift`, `BoulderTrackerWatch/WatchSyncCoordinator.swift`, `BoulderTrackerWatch/WatchRootView.swift`.

- `PhoneSyncCoordinator.init(context:link:queue:)` with production convenience `init(context:)` building `WatchConnectivityLink` + `.inApplicationSupport(named: "phone-sync-queue.json")`. Store `link: any SyncLinking`.
- `WatchSyncCoordinator.init(link:queue:liveSessionFileURL:)` + production `init()`.
- [ ] Build + full existing test suite green. Commit `refactor: inject sync link and queue into coordinators`.

### Task 2 (#12, #13): Logging + no more silent failures

**Files:** Create `Shared/AppLoggers.swift`, `BoulderTracker/Models/ModelContextSaveReporting.swift`. Modify all 18 `try? …save()` sites, `WatchConnectivityLink.swift`, `LiveWorkoutSession.swift`, `SampleDataToggleRow.swift`, `PendingEventQueue.swift`, `WatchLiveSession.swift`, `BoulderTrackerApp.swift`.

```swift
// Shared/AppLoggers.swift
import OSLog
extension Logger {
    private static let subsystem = "com.liammelkersson.BoulderTracker"
    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let sync = Logger(subsystem: subsystem, category: "sync")
    static let health = Logger(subsystem: subsystem, category: "health")
}
```

```swift
// BoulderTracker/Models/ModelContextSaveReporting.swift
extension ModelContext {
    /// Saves and logs failure; UI flows have no rethrow path, so the log is the
    /// only surface for a store-level failure.
    func saveReportingFailure(operation: StaticString) {
        do { try save() } catch {
            Logger.persistence.error("Save failed during \(operation): \(error)")
        }
    }
}
```

- [ ] Replace every `try? modelContext.save()` / `try? context.save()` production site with `saveReportingFailure(operation:)` (18 sites listed in audit §3e).
- [ ] `WatchConnectivityLink.deliverToMainActor`: log decode failures (`Logger.sync.error`). `activationDidCompleteWith`: log error if present. `sendImmediately`/`transferGuaranteed` encode failures: log.
- [ ] `PendingEventQueue.persist`/`storedEnvelopes`: log failures instead of bare `try?`.
- [ ] `WatchLiveSession.persist`: log write failures.
- [ ] `LiveWorkoutSession.workoutSession(_:didFailWithError:)`: log + clear `session`/`builder` on main actor. `didChangeTo`: log transitions at debug.
- [ ] `SampleDataToggleRow`: do/catch with `Logger.persistence.error`.
- [ ] `BoulderTrackerApp.init`: seeding gets its own `do/catch` that logs and continues; only container creation keeps `fatalError`.
- [ ] Build + tests green. Commit `fix: log persistence, sync, and workout failures instead of swallowing them`.

### Task 3 (#2): Complete the `.persisted` / `isInvalidated` sweep

**Files:** Modify `SessionSummaryScreen.swift`, `LiveSessionView.swift`, `ActivitiesView.swift`, `AchievementsGridView.swift`, `ProfileView.swift`, `SessionDetailSheet.swift`.

- Views holding a `let session: Session` that can be deleted mid-presentation (`SessionSummaryScreen` via Discard, `SessionDetailSheet` via delete, `LiveSessionView` via inbox races) get a top-of-body guard: `if session.isInvalidated { Color.clear } else { content }`.
- `@Query` arrays feeding aggregation get `.persisted`: `ActivitiesView.finishedSessions`, `AchievementsGridView.finishedSessions`, `ProfileView.exportSessions`, `SessionSummaryScreen`/`LiveSessionView` `allSessions` usages.
- [ ] Build + tests. Commit `fix: guard remaining session views against invalidated models`.

### Task 4 (#7): Single-live-session invariant + watch envelope dedup

**Files:** Modify `Services/SessionSyncInbox.swift`, `Services/PhoneSyncCoordinator.swift`, `Shared/Sync/WatchLiveSession.swift`, `BoulderTrackerWatch/WatchSyncCoordinator.swift`. Tests: `SessionSyncInboxTests.swift`, `WatchLiveSessionTests.swift`.

Behavior:
1. Inbox `adoptSession`: after inserting the new live session, close every *other* live session: `other.endTime = max(other.startTime, newest.startTime)` keeping only the latest-starting session live.
2. `answerLiveSessionRequest`: fetch with `sortBy: [SortDescriptor(\.startTime, order: .reverse)]` so the pick is deterministic (latest live session).
3. `WatchLiveSession.apply(.sessionStarted)`: ignore when `payload.sessionSyncID == snapshot?.sessionSyncID` (re-delivery must not wipe the tally); when a different session arrives, adopt only if `payload.startTime >= snapshot.startTime`.
4. Watch-side envelope dedup: `WatchSyncCoordinator.route` skips envelopes whose id was already applied (persisted set, bounded 512, stored beside the snapshot file) — both channels deliver every envelope, and today the second delivery double-counts attempts.

TDD: write failing tests first —
- inbox: watch session start while phone session live → exactly one `isLive` row.
- watch: duplicate `sessionStarted` envelope keeps problems; duplicate `attemptLogged` envelope counts once.
- [ ] Commit `fix: keep one live session and de-duplicate watch deliveries`.

### Task 5 (#9, #10): Catalog re-push + missing announcements + sessionDeleted event

**Files:** Modify `Shared/Sync/SessionSyncEvent.swift` (add `case sessionDeleted(SessionDeletePayload)`), `Shared/Sync/WatchLiveSession.swift` (clear snapshot on matching delete), `Services/PhoneSyncCoordinator.swift` (`publishCatalog()` public, `announceDeletion(of:)`), `Profile/PreferencesSection.swift` (+coordinator env, `.onChange` on grade system & HealthKit toggle → `publishCatalog()`), `Profile/GymListSection.swift` (GymEditorSheet save → `publishCatalog()`), `Home/SessionDetailSheet.swift` (delete → `announceDeletion`; `saveEdits` → `announceEnd`), `Home/SessionSummaryScreen.swift` (discard → `announceDeletion`). Tests: `SessionSyncCodingTests` round-trip for new case, `WatchLiveSessionTests` for delete-clears-snapshot.

Note: problem creation without attempts is intentionally not announced — the watch tally only renders attempt counts, and every attempt path already announces.

- [ ] Commit `feat: push catalog on preference and gym changes and sync session deletion`.

### Task 6 (#11): Outbox/link robustness

**Files:** Modify `Shared/Sync/WatchConnectivityLink.swift`, `Shared/Sync/SyncLinking.swift` (+`onLinkReady`), `Shared/Sync/PendingEventQueue.swift`, `Services/SessionSyncInbox.swift`, coordinators. Tests: `PendingEventQueueTests`, `SessionSyncOutboxTests`, `SessionSyncInboxTests`.

1. `completeTransfer`: always `removeValue`; fire `onDelivered` only when succeeded (fixes unbounded leak).
2. `activationDidCompleteWith` + new `sessionReachabilityDidChange` → `onLinkReady` → coordinators call `outbox.resendPending()`.
3. `PendingEventQueue`: cap 500 envelopes, drop oldest on overflow (log).
4. Inbox orphan buffer: cap 256 envelopes total (drop oldest, log); prune `appliedEventIDs` to newest 512 on append.
- [ ] Commit `fix: retry pending sync on link readiness and bound sync buffers`.

### Task 7 (#14b/c): Coordinator tests + watch test target

**Files:** Create `BoulderTrackerTests/PhoneSyncCoordinatorTests.swift`, `BoulderTrackerTests/PhoneWatchSyncIntegrationTests.swift`, `BoulderTrackerWatchTests/WatchSyncCoordinatorTests.swift`. Modify `project.yml` (watch unit-test bundle + scheme test block).

- PhoneSyncCoordinator (via FakeSyncLink + in-memory context + temp-file queue): `start()` sends catalog; `liveSessionRequest` answers with latest live snapshot + catalog; `announceAttempt` skips sessions without syncID.
- Integration: watch coordinator's outbox events piped into phone coordinator's link → phone store contains session + counts; then phone announces → watch snapshot matches. (Drive both with fakes; no WCSession.)
- Watch target tests: routing catalog updates, dedup, finish flow state.
- [ ] Commit `test: cover sync coordinators end to end and add watch test target`.

### Task 8 (#5): Finish shoes

**Files:** Modify `Home/GymPickerSheet.swift` (shoe pills, optional), `Home/SessionSummaryScreen.swift` (shoe picker section), `Profile/ShoeListSection.swift` (delete button + confirmation in editor), `Models/Shoe.swift` (drop dead `syncID`), `Profile/SessionDataExport.swift` (`shoe: String?` field), `SampleDataGenerator.swift` (drop syncID use if any). Tests: `ShoeTests` (delete nullifies sessions — exists? extend), export test.

- [ ] Commit `feat: pick shoes at session start and summary, allow shoe deletion, export shoe`.

### Task 9 (#17): Deletion for gyms, partners, problems

**Files:** Modify `Profile/GymListSection.swift`, `Profile/PartnerListSection.swift` (destructive Delete button + confirmationDialog in editor sheets), `Home/ProblemTile.swift` (context-menu Delete with confirmation; removes photo file + model). Gym delete also `publishCatalog()`.

- [ ] Commit `feat: allow deleting gyms, partners, and problems`.

### Task 10 (#16): CloudKit backup

**Files:** Modify `Models/Achievement.swift` (drop `.unique`; dedup stays in the existing unlockedIDs guard), `Models/Session.swift` (defaults: `date`, `startTime`, `climbType`, `partners = []`, `problems = []`), `BoulderTracker/BoulderTracker.entitlements` (iCloud CloudKit service + container `iCloud.com.liammelkersson.BoulderTracker` + aps-environment), `project.yml` (`INFOPLIST_KEY_UIBackgroundModes: remote-notification`), `App/BoulderTrackerApp.swift`:

```swift
private static func makeContainer() throws -> ModelContainer {
    let schema = Schema([Session.self, SessionProblem.self, Gym.self, Partner.self,
                         RoadmapProgress.self, Achievement.self, Shoe.self])
    do {
        return try ModelContainer(for: schema, configurations:
            ModelConfiguration(schema: schema, cloudKitDatabase: .automatic))
    } catch {
        Logger.persistence.error("CloudKit container unavailable, falling back to local: \(error)")
        return try ModelContainer(for: schema, configurations:
            ModelConfiguration(schema: schema, cloudKitDatabase: .none))
    }
}
```

Verification limit: real CloudKit sync needs a signed device + iCloud account; local fallback keeps the app working everywhere else. Tests stay on in-memory containers.
- [ ] Commit `feat: back up the store to CloudKit with local fallback`.

### Task 11 (#23): Accessibility

**Files:** Create `BoulderTracker/Design/ScaledFont.swift` (ViewModifier with `@ScaledMetric(relativeTo:)`); mechanical sweep of `.font(.system(size:…))` → `.scaledFont(…)` across the iOS app (~135 sites, script-assisted, watch left as is); labels on icon-only buttons (detail-sheet close, month steppers, achievements back); `.accessibilityElement(children: .combine)` on `StatTile`, `ProblemTile` result buttons get value labels; chart summaries on `StyleRadialChart`/`VolumeTrendChart`.

- [ ] Commit in two parts: `feat: scale text with Dynamic Type` (mechanical) and `feat: label icon-only controls and charts for VoiceOver`.

### Task 12 (#25): Polish

- `PartnerChip`: FNV-1a over `name.unicodeScalars` for a launch-stable color index.
- `SessionSummaryScreen`: confirmation dialog before Discard.
- New `Design/ThemedNotesField.swift` (`TextField(axis: .vertical)`, `lineLimit(1...4)`); use for session/problem/retro notes.
- `ProfileView` footer reads `CFBundleShortVersionString`; `project.yml` gets `MARKETING_VERSION: 1.0.0`.
- `ThemePalette.success = Color(hex: 0x14A876)`; replace the five hard-coded uses.
- `PreferencesSection`: drop always-false `isLast` parameter.
- Fix grade table in `docs/superpowers/specs/2026-08-28-boulder-tracker-design.md` to match shipped `ColorGrade` (green→white ascending, yellow = warm-up, unknown).
- [ ] Commit `fix: polish partner colors, discard confirm, notes fields, version footer, color tokens`.

## Verification

Full suite + build of both schemes after Tasks 2, 4, 7, 10, 12:
`xcodebuild test -scheme BoulderTracker -destination 'platform=iOS Simulator,id=4F06D682-66C1-4FD0-A29E-B7615C3E960F'`
Watch tests: `xcodebuild test -scheme BoulderTrackerWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)'`
