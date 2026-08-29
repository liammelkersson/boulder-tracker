# watchOS Companion App — Design

Date: 2026-08-29
Status: Approved, ready for implementation planning

## Goal

Log climbing sessions from Apple Watch, including session duration and heart
rate, with the data appearing in the existing iPhone app.

The watch must work with the phone locked in a gym locker: no network, no
Bluetooth range, potentially for a two-hour session. Data reaches the phone
when the devices are next in range.

## Decisions

| Question | Decision |
|---|---|
| Session ownership | Watch is standalone-capable. Either device can start a session. |
| Heart rate storage | Summary only (avg, max, active calories) on `Session`. Samples stay in Apple Health. |
| Watch feature scope | Quick log (grade → result) plus gym and climb-type pick at start. |
| Live sync | Two-way mirror while reachable; queued and replayed when not. |
| Health workout owner | Watch owns it when the watch is tracking; phone keeps today's path otherwise. |
| Transport | WatchConnectivity plus a file-backed watch queue. No CloudKit. |
| Code sharing | Shared source folder compiled into both targets. No Swift package. |

Rejected alternatives and why:

- **CloudKit-backed SwiftData** — requires every model property optional with
  no unique constraints (a real migration of the current schema), and sync
  latency is minutes, which cannot drive a mirrored live timer.
- **Local Swift package `BoulderCore`** — the SwiftData `@Model` classes must
  stay in the app target regardless, so the package would hold only enums and
  DTOs. Ceremony above the payoff at this size. Revisit if the watch target
  grows real logic.
- **Duplicated DTOs on the watch** — `ColorGrade` defined twice is the exact
  drift bug that breaks logging silently.

## Targets

`project.yml` gains `watchOS: "26.0"` under `options.deploymentTarget` and one
new target.

```
BoulderTrackerWatch:
  type: application
  platform: watchOS
  sources: [BoulderTrackerWatch, Shared]
  settings:
    TARGETED_DEVICE_FAMILY: "4"
    INFOPLIST_KEY_WKApplication: true
    INFOPLIST_KEY_WKCompanionAppBundleIdentifier: com.liammelkersson.BoulderTracker
    INFOPLIST_KEY_WKBackgroundModes: workout-processing
    INFOPLIST_KEY_NSHealthUpdateUsageDescription: "Save climbing sessions as workouts in Apple Health."
    INFOPLIST_KEY_NSHealthShareUsageDescription: "Read heart rate and active energy during a climbing session."
    CODE_SIGN_ENTITLEMENTS: BoulderTrackerWatch/BoulderTrackerWatch.entitlements
```

The watch entitlements file carries `com.apple.developer.healthkit`.
`workout-processing` keeps heart-rate collection alive with the wrist down and
the app backgrounded.

The iOS target gains `dependencies: [{ target: BoulderTrackerWatch, embed: true }]`
so the watch app ships inside the iOS app bundle. Verify after the first
`xcodegen generate` that the embed copy phase targets
`$(CONTENTS_FOLDER_PATH)/Watch`; add an explicit `copy.subpath` if XcodeGen
does not infer it.

The existing `postGenCommand` `.icon` patch stays as-is.

## Shared code

New top-level `Shared/` directory, listed in `sources` for both app targets.

Moved in unchanged (already pure Foundation `Codable` value types):
`ColorGrade`, `AttemptResult`, `ClimbType`, `RouteStyle`.

New, under `Shared/Sync/`: the event types, envelope, codec, transport
protocol, WatchConnectivity link, inbox, and pending queue described below.

The iOS target keeps globbing `BoulderTracker/`. Nothing else moves.

Constraint to hold: files under `Shared/` import Foundation only. No SwiftUI,
no SwiftData, no UIKit — the shared folder has no compiler-enforced boundary,
so this is a review rule.

## Model changes

`Session` gains:

- `syncID: UUID` — stable cross-device identity. SwiftData's
  `PersistentIdentifier` is device-local and unusable as a sync key.
- `avgHeartRate: Double?`, `maxHeartRate: Double?`, `activeCalories: Double?`
- `isWatchTracked: Bool = false` — set when any event arrives from the watch.
  Tells the phone not to write its own Health workout.
- `appliedEventIDs: [UUID]` — dedup set backing idempotent merge.

`SessionProblem` gains `syncID: UUID`.

All additive with defaults, so lightweight migration covers it and no
migration plan type is needed. Existing rows get fresh `syncID`s, which is
correct — those sessions predate sync.

## Sync protocol

Every mutation crosses the wire as an **additive event**, never as absolute
state. Additive counter increments commute, so a two-way merge has no
conflicts to resolve: no last-writer-wins, and no lost logs when both devices
log while disconnected.

```swift
enum SessionSyncEvent: Codable {
    case sessionStarted(SessionStartPayload)      // syncID, startTime, gymName, climbType
    case problemCreated(ProblemCreatedPayload)    // problemSyncID, sessionSyncID, colorGrade
    case attemptLogged(AttemptLogPayload)         // problemSyncID, result, loggedAt
    case sessionEnded(SessionEndPayload)          // syncID, endTime
    case workoutRecorded(WorkoutSummaryPayload)   // syncID, workoutID, avgHR, maxHR, calories
    case liveSessionRequest                       // watch cold start, asks for current state
    case sessionSnapshot(SessionSnapshotPayload)  // reply to the above, absolute counts
    case phoneCatalog(PhoneCatalogPayload)        // gyms + healthKitSync preference, phone → watch
}
```

Each event ships inside `SyncEnvelope { id: UUID, sentAt: Date, event: SessionSyncEvent }`.
The envelope `id` is the dedup key.

`SessionSyncCoding` converts an envelope to and from the `[String: Any]`
dictionary WatchConnectivity requires, via `JSONEncoder` into a single data
value.

## Transport

`SyncLinking` is a protocol — send an envelope, receive a stream of them — so
merge logic is testable against a fake link. `WatchConnectivityLink` is the
one real implementation, shared by both platforms.

Every envelope goes out twice:

- `sendMessage` when the peer is reachable — low latency, drives the live mirror.
- `transferUserInfo` always — guaranteed, FIFO, survives app termination and
  out-of-range periods.

Double delivery costs nothing because application is idempotent. This is what
makes the locker case work: the phone is unreachable for ninety minutes and
the queue drains on reconnect.

## Merge

`SessionSyncInbox` on the phone and its watch counterpart follow one rule:
if the envelope `id` is in `appliedEventIDs`, drop it; otherwise apply it and
record the id.

Applying `.attemptLogged` calls the existing `SessionProblem.recordResult`.
`.problemCreated` for a `problemSyncID` that already exists is a no-op.

Events can arrive out of order — a log before the session that owns it. The
inbox holds orphans in a pending buffer keyed by unknown `sessionSyncID` and
replays them when the parent arrives. The buffer is bounded and cleared on
session end.

## Durability

`PendingEventQueue` on the watch is file-backed JSON: append before send,
remove on `transferUserInfo` completion. If the app is killed mid-session the
queue survives and drains on next launch. The watch also persists a snapshot
of the live session — start time, gym, per-problem counts — so the UI rebuilds
after a crash.

The phone has no outbox file. SwiftData is already durable, and re-sending on
reconnect is unnecessary because the watch reconstructs from its own store.
Phone-to-watch traffic is `.phoneCatalog` and phone-side logs, neither of
which needs to survive a phone restart.

## Workout ownership

When the watch is tracking, `LiveWorkoutSession` runs an `HKWorkoutSession`
with `HKLiveWorkoutDataSource`, giving real heart rate, calories, and activity
ring credit. On end it finishes the workout, computes avg and max heart rate
and active calories, and sends `.workoutRecorded`. The phone writes the
workout UUID and heart-rate summary onto the `Session`.

`SessionCompletion.saveWorkout` gains one guard: skip when
`session.isWatchTracked`, returning a new `WorkoutSaveResult.recordedByWatch`.
Phone-only sessions keep today's `HKWorkoutBuilder` path untouched, tests
included.

HealthKit authorization on the watch is separate from the phone's and is
requested at first session start.

## Watch screens

**Idle** — a `Start Session` action: climb-type pills, then the gym list from
the cached phone catalog, which is persisted on the watch so it works with the
phone off. An empty catalog starts the session with no gym; it is assignable
on the phone later.

**Live** — `TimelineView` timer, current BPM, grade tally, and a grade list.
Tap a grade, then pick Flash / Send / Fall — the same two-tap shape as
`QuickLogRow`, sized for cold hands. `End` sits at the bottom of the crown
scroll behind a confirmation.

**Summary** — duration, sends, average heart rate. Dismisses to idle.

## Cold-start catch-up

The phone cannot launch the watch app. Start a session on the phone, put the
watch on later, and the watch does not know a session is running.

On launch with no local session, the watch sends `.liveSessionRequest`; the
phone replies with `.sessionSnapshot` carrying absolute counts, or with a
snapshot marked empty when no session is live. A snapshot is applied only
into empty watch state, never mid-mirror. The watch then starts its workout
and normal mirroring continues. The same mechanism prevents accidental double
sessions.

Accepted consequence: when a session begins on the phone, heart-rate coverage
starts when the watch app is opened, not at session start. Starting on the
watch avoids this.

## Testing

In the existing iOS test target, following current patterns:

- `SessionSyncEventCodecTests` — round-trip every event case.
- `SessionSyncInboxTests` — events produce the right SwiftData state; applying
  the same envelope twice yields one log; out-of-order orphans replay; end
  sets `endTime`; a snapshot is ignored when a live session already exists.
- `PendingEventQueueTests` — append, drain, survive across instances.
- `SessionCompletionTests` — new case: `isWatchTracked` yields
  `.recordedByWatch` and writes no workout.
- `ModelRoundTripTests` — `syncID` and the heart-rate fields.

`LiveWorkoutSession` is not unit tested. It is a thin `HKLiveWorkoutDataSource`
wrapper only verifiable on real hardware; it is verified by hand on device.

## Out of scope

Complications, Digital Crown grade scrubbing, named problems, style tagging,
partners, photos and notes on the watch, watch-side stats, watch-side editing
of past sessions, and standalone install without the iPhone app.
