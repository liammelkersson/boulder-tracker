# CloudKit Backup

Added 2026-09-01 (`feat: back up the store to CloudKit with local fallback`).
The SwiftData store now syncs to the user's private CloudKit database, so a
lost or replaced phone restores its climbing history. Without an iCloud
account (or missing capability) the app silently falls back to the same
device-local store as before.

## What changed

- `BoulderTrackerApp.makeContainer()` builds the container twice if needed:
  first with `cloudKitDatabase: .automatic`, and on failure with `.none`,
  logging the reason under the `persistence` category.
- `BoulderTracker.entitlements` gained the iCloud CloudKit service and the
  container `iCloud.com.liammelkersson.BoulderTracker`.
- Model changes forced by CloudKit's rules:
  - No `@Attribute(.unique)` — removed from `Achievement` and
    `RoadmapProgress`. Duplicate-achievement protection lives in the save
    path (`SessionSummaryScreen.completeSession` checks the unlocked-id set).
  - Every attribute has a default value; every to-one relationship is
    optional.
  - Every relationship has an explicit inverse (`Gym.sessions`,
    `Partner.sessions`, `Shoe.sessions`).
  - To-many relationships must be *optional* — a `= []` default is not
    enough. `Session.partners`/`Session.problems` are stored as private
    optionals (`storedPartners`/`storedProblems`) with non-optional computed
    accessors, and `@Relationship(originalName:)` keeps the on-disk schema of
    the previously shipped non-optional columns, so existing data migrates
    lightweight with no loss.
- Tests are unaffected: `makeInMemoryContainer()` passes
  `cloudKitDatabase: .none` explicitly, because the test host now carries
  iCloud entitlements and would otherwise try CloudKit.

## Manual steps before it syncs for real

1. In the Apple Developer portal (team `6KKKY36H7B`), make sure the iCloud
   container `iCloud.com.liammelkersson.BoulderTracker` exists and is
   assigned to the `com.liammelkersson.BoulderTracker` app id. Xcode's
   automatic signing usually creates it on the first device build.
2. Build to a real device signed into iCloud. The simulator has no iCloud
   account, so it always runs on the local fallback (visible in the console
   as `CKAccountStatusNoAccount`).
3. Verify: log a session, then check CloudKit Console → the private database
   of the container for `CD_Session` records, or install on a second device
   with the same Apple ID and confirm the history appears.
4. First launch on the production schema: promote the development CloudKit
   schema to production in CloudKit Console before a TestFlight/App Store
   build, or fresh installs from those builds cannot sync.

## Known limitations

- No push-driven sync: the remote-notification background mode is not
  enabled, so changes from another device arrive on launch/foregrounding,
  not instantly.
- The watch app has no SwiftData store and is unaffected; it still syncs
  with the phone over WatchConnectivity only.
- Demo rows from the sample-data toggle are flagged (`isSampleData`) but do
  sync like any other row; removing them on one device removes them
  everywhere once both devices have synced.
- CloudKit merges concurrent edits per record; the app's own single-live-
  session invariant (sync inbox) is what resolves session-level conflicts.
