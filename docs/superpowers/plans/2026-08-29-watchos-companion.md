# watchOS Companion App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Log climbing sessions from Apple Watch — duration, heart rate, and per-grade attempts — with the data merging into the existing iPhone SwiftData store.

**Architecture:** A new watchOS app target shares pure-Foundation value types with the iOS app through a top-level `Shared/` folder compiled into both. Mutations cross the wire as additive, idempotent events over WatchConnectivity (`sendMessage` for latency plus `transferUserInfo` for guaranteed delivery), buffered in a file-backed queue on the watch so a session survives the phone being locked in a locker. The watch owns the `HKWorkoutSession` when it is tracking; the phone keeps its existing `HKWorkoutBuilder` path otherwise.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, WatchConnectivity, HealthKit, Swift Testing, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-08-29-watchos-companion-design.md`

## Global Constraints

- iOS deployment target **26.0** (iPhone only, `TARGETED_DEVICE_FAMILY: "1"`). watchOS deployment target **26.0** (`TARGETED_DEVICE_FAMILY: "4"`).
- Swift version **6.0**. `DEVELOPMENT_TEAM: 6KKKY36H7B`, `CODE_SIGN_STYLE: Automatic`.
- No third-party runtime packages. XcodeGen (2.46.0) is a dev tool only.
- Every file under `Shared/` imports **Foundation and Observation only**. No SwiftUI, no SwiftData, no UIKit, no HealthKit — the folder has no compiler-enforced boundary, so this is a review rule. Violating it breaks the watch build.
- `project.yml` is the source of truth. After every edit to it run `xcodegen generate`; never hand-edit `BoulderTracker.xcodeproj`. The existing `postGenCommand` `.icon` patch must survive untouched.
- iOS test command (all tasks): `xcodebuild test -project BoulderTracker.xcodeproj -scheme BoulderTracker -destination "platform=iOS Simulator,name=iPhone 17 Pro" -quiet`. If that simulator is absent, run `xcrun simctl list devices available` and substitute the newest available iPhone everywhere in this plan.
- watch build command (Tasks 1, 10, 11): `xcodebuild build -project BoulderTracker.xcodeproj -scheme BoulderTrackerWatch -destination "platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)" -quiet`. If that simulator is absent, run `xcrun simctl list devices available | grep Watch` and substitute the newest available watch everywhere in this plan.
- Tests use **Swift Testing** (`import Testing`, `@Test`, `#expect`), never XCTest. SwiftData tests use the existing `makeInMemoryContainer()` helper in `BoulderTrackerTests/ModelRoundTripTests.swift`.
- Commit messages: plain conventional style (`feat:`, `test:`, `refactor:`, `chore:`), **no Co-Authored-By lines**.
- Sync is best-effort — a WatchConnectivity failure must never block or fail a local save.
- Naming: no file or function named `manager`, `handler`, `helper`, `util`, `process`, `handle`, `build`, `get`, `set`. Functions ≤30 LOC, files ≤300 LOC, one type per file.

---

### Task 1: watchOS target and Shared folder

**Files:**
- Move: `BoulderTracker/Models/ColorGrade.swift` → `Shared/ColorGrade.swift`
- Move: `BoulderTracker/Models/AttemptResult.swift` → `Shared/AttemptResult.swift`
- Move: `BoulderTracker/Models/ClimbType.swift` → `Shared/ClimbType.swift`
- Move: `BoulderTracker/Models/RouteStyle.swift` → `Shared/RouteStyle.swift`
- Create: `BoulderTrackerWatch/BoulderTrackerWatchApp.swift`
- Create: `BoulderTrackerWatch/BoulderTrackerWatch.entitlements`
- Modify: `project.yml`

**Interfaces:**
- Consumes: nothing.
- Produces: a `Shared/` source folder compiled into both app targets, and a buildable `BoulderTrackerWatch` scheme. All later tasks put shared code in `Shared/` and watch code in `BoulderTrackerWatch/`.

- [ ] **Step 1: Move the four shared enums**

```bash
mkdir -p Shared BoulderTrackerWatch
git mv BoulderTracker/Models/ColorGrade.swift Shared/ColorGrade.swift
git mv BoulderTracker/Models/AttemptResult.swift Shared/AttemptResult.swift
git mv BoulderTracker/Models/ClimbType.swift Shared/ClimbType.swift
git mv BoulderTracker/Models/RouteStyle.swift Shared/RouteStyle.swift
```

Their contents do not change — all four are already `Foundation`-only `Codable` value types.

- [ ] **Step 2: Write the watch app entry point**

Create `BoulderTrackerWatch/BoulderTrackerWatchApp.swift`:

```swift
import SwiftUI

@main
struct BoulderTrackerWatchApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Boulder Tracker")
        }
    }
}
```

Task 11 replaces the body with the real root view.

- [ ] **Step 3: Write the watch entitlements**

Create `BoulderTrackerWatch/BoulderTrackerWatch.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.healthkit</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 4: Add the watchOS target to project.yml**

In `project.yml`, add `watchOS: "26.0"` under `options.deploymentTarget` alongside the existing `iOS: "26.0"`.

Add `- path: Shared` to the iOS `BoulderTracker` target's `sources` list (keeping the two existing entries).

Add the new target under `targets:`:

```yaml
  BoulderTrackerWatch:
    type: application
    platform: watchOS
    sources:
      - path: BoulderTrackerWatch
      - path: Shared
    settings:
      base:
        SWIFT_VERSION: "6.0"
        DEVELOPMENT_TEAM: 6KKKY36H7B
        CODE_SIGN_STYLE: Automatic
        TARGETED_DEVICE_FAMILY: "4"
        PRODUCT_BUNDLE_IDENTIFIER: com.liammelkersson.BoulderTracker.watchkitapp
        GENERATE_INFOPLIST_FILE: true
        INFOPLIST_KEY_WKApplication: true
        INFOPLIST_KEY_WKCompanionAppBundleIdentifier: com.liammelkersson.BoulderTracker
        INFOPLIST_KEY_WKBackgroundModes: workout-processing
        INFOPLIST_KEY_NSHealthUpdateUsageDescription: "Save climbing sessions as workouts in Apple Health."
        INFOPLIST_KEY_NSHealthShareUsageDescription: "Read heart rate and active energy during a climbing session."
        CODE_SIGN_ENTITLEMENTS: BoulderTrackerWatch/BoulderTrackerWatch.entitlements
```

Add the embed dependency to the `BoulderTracker` target (create a `dependencies:` key on it — it has none today):

```yaml
    dependencies:
      - target: BoulderTrackerWatch
        embed: true
        copy:
          destination: productsDirectory
          subpath: "$(CONTENTS_FOLDER_PATH)/Watch"
```

Add a scheme under `schemes:`:

```yaml
  BoulderTrackerWatch:
    build:
      targets:
        BoulderTrackerWatch: all
```

- [ ] **Step 5: Generate and build both platforms**

```bash
xcodegen generate
xcodebuild build -project BoulderTracker.xcodeproj -scheme BoulderTrackerWatch -destination "platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)" -quiet
```

Expected: watch build succeeds.

Then the global iOS test command. Expected: all existing tests still PASS — moving the enums changed no code, only file locations.

If the embed copy phase is rejected by XcodeGen, check `xcodegen generate` output for the exact error before changing the `copy` block.

- [ ] **Step 6: Commit**

```bash
git add project.yml BoulderTracker.xcodeproj Shared BoulderTrackerWatch BoulderTracker
git commit -m "feat: add watchOS app target and shared source folder"
```

---

### Task 2: Sync event model and codec

**Files:**
- Create: `Shared/Sync/SessionSyncEvent.swift`
- Create: `Shared/Sync/SyncEnvelope.swift`
- Create: `Shared/Sync/SessionSyncCoding.swift`
- Test: `BoulderTrackerTests/SessionSyncCodingTests.swift`

**Interfaces:**
- Consumes: `ColorGrade`, `AttemptResult`, `ClimbType` from Task 1.
- Produces: `SessionSyncEvent` (cases `.sessionStarted`, `.attemptLogged`, `.sessionEnded`, `.workoutRecorded`, `.liveSessionRequest`, `.sessionSnapshot`, `.phoneCatalog`); payload structs `SessionStartPayload`, `AttemptLogPayload`, `SessionEndPayload`, `WorkoutSummaryPayload`, `SessionSnapshotPayload`, `LiveSessionSnapshot`, `ProblemCountsSnapshot`, `GymSnapshot`, `PhoneCatalogPayload`; `SyncEnvelope(id:sentAt:event:)`; `SessionSyncCoding.messagePayload(for:)` / `.envelope(from:)`.

- [ ] **Step 1: Write the failing test**

Create `BoulderTrackerTests/SessionSyncCodingTests.swift`:

```swift
import Testing
import Foundation
@testable import BoulderTracker

struct SessionSyncCodingTests {
    private func roundTrip(_ event: SessionSyncEvent) throws -> SessionSyncEvent {
        let envelope = SyncEnvelope(event: event)
        let payload = try SessionSyncCoding.messagePayload(for: envelope)
        let decoded = try SessionSyncCoding.envelope(from: payload)
        #expect(decoded.id == envelope.id)
        return decoded.event
    }

    @Test func sessionStartedRoundTrips() throws {
        let sessionSyncID = UUID()
        let event = SessionSyncEvent.sessionStarted(SessionStartPayload(
            sessionSyncID: sessionSyncID, startTime: Date(timeIntervalSince1970: 1000),
            gymName: "Klättervigören Jönköping", climbType: .topRope
        ))
        #expect(try roundTrip(event) == event)
    }

    @Test func attemptLoggedRoundTrips() throws {
        let event = SessionSyncEvent.attemptLogged(AttemptLogPayload(
            sessionSyncID: UUID(), problemSyncID: UUID(), colorGrade: .black,
            result: .flash, loggedAt: Date(timeIntervalSince1970: 2000)
        ))
        #expect(try roundTrip(event) == event)
    }

    @Test func workoutRecordedRoundTrips() throws {
        let event = SessionSyncEvent.workoutRecorded(WorkoutSummaryPayload(
            sessionSyncID: UUID(), workoutID: UUID(),
            avgHeartRate: 132.5, maxHeartRate: 171, activeCalories: 480
        ))
        #expect(try roundTrip(event) == event)
    }

    @Test func snapshotWithProblemsRoundTrips() throws {
        let event = SessionSyncEvent.sessionSnapshot(SessionSnapshotPayload(
            liveSession: LiveSessionSnapshot(
                sessionSyncID: UUID(), startTime: Date(timeIntervalSince1970: 3000),
                gymName: nil, climbType: .bouldering,
                problems: [ProblemCountsSnapshot(
                    problemSyncID: UUID(), colorGrade: .red,
                    flashCount: 1, sendCount: 2, fallCount: 3
                )]
            )
        ))
        #expect(try roundTrip(event) == event)
    }

    @Test func emptySnapshotAndRequestRoundTrip() throws {
        #expect(try roundTrip(.liveSessionRequest) == .liveSessionRequest)
        let empty = SessionSyncEvent.sessionSnapshot(SessionSnapshotPayload(liveSession: nil))
        #expect(try roundTrip(empty) == empty)
    }

    @Test func phoneCatalogRoundTrips() throws {
        let event = SessionSyncEvent.phoneCatalog(PhoneCatalogPayload(
            gyms: [GymSnapshot(name: "Klättervigören Jönköping", isDefault: true)],
            healthKitSyncEnabled: false
        ))
        #expect(try roundTrip(event) == event)
    }

    @Test func decodingRejectsPayloadWithoutEnvelope() {
        #expect(throws: SyncCodingFailure.self) {
            try SessionSyncCoding.envelope(from: ["wrong": 1])
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run the global iOS test command.
Expected: compile FAIL — `cannot find 'SessionSyncEvent' in scope`.

- [ ] **Step 3: Write the payloads and event enum**

Create `Shared/Sync/SessionSyncEvent.swift`:

```swift
import Foundation

struct SessionStartPayload: Codable, Sendable, Equatable {
    let sessionSyncID: UUID
    let startTime: Date
    let gymName: String?
    let climbType: ClimbType
}

/// Carries the grade so a receiver that has never seen this problem can create it,
/// which removes any ordering requirement between logs within a session.
struct AttemptLogPayload: Codable, Sendable, Equatable {
    let sessionSyncID: UUID
    let problemSyncID: UUID
    let colorGrade: ColorGrade
    let result: AttemptResult
    let loggedAt: Date
}

struct SessionEndPayload: Codable, Sendable, Equatable {
    let sessionSyncID: UUID
    let endTime: Date
}

struct WorkoutSummaryPayload: Codable, Sendable, Equatable {
    let sessionSyncID: UUID
    let workoutID: UUID
    let avgHeartRate: Double?
    let maxHeartRate: Double?
    let activeCalories: Double?
}

struct ProblemCountsSnapshot: Codable, Sendable, Equatable {
    let problemSyncID: UUID
    let colorGrade: ColorGrade
    let flashCount: Int
    let sendCount: Int
    let fallCount: Int
}

struct LiveSessionSnapshot: Codable, Sendable, Equatable {
    let sessionSyncID: UUID
    let startTime: Date
    let gymName: String?
    let climbType: ClimbType
    let problems: [ProblemCountsSnapshot]
}

/// `liveSession` is nil when the responder has no session running.
struct SessionSnapshotPayload: Codable, Sendable, Equatable {
    let liveSession: LiveSessionSnapshot?
}

struct GymSnapshot: Codable, Sendable, Equatable {
    let name: String
    let isDefault: Bool
}

struct PhoneCatalogPayload: Codable, Sendable, Equatable {
    let gyms: [GymSnapshot]
    let healthKitSyncEnabled: Bool
}

/// Every mutation crosses the wire as an additive event. Increments commute, so a
/// two-way merge has no conflicts and replaying an event changes nothing.
enum SessionSyncEvent: Codable, Sendable, Equatable {
    case sessionStarted(SessionStartPayload)
    case attemptLogged(AttemptLogPayload)
    case sessionEnded(SessionEndPayload)
    case workoutRecorded(WorkoutSummaryPayload)
    case liveSessionRequest
    case sessionSnapshot(SessionSnapshotPayload)
    case phoneCatalog(PhoneCatalogPayload)
}
```

- [ ] **Step 4: Write the envelope**

Create `Shared/Sync/SyncEnvelope.swift`:

```swift
import Foundation

/// Wraps an event with the identity used for delivery de-duplication. The same
/// envelope is sent over both WatchConnectivity channels, so peers see duplicates.
struct SyncEnvelope: Codable, Sendable, Equatable {
    let id: UUID
    let sentAt: Date
    let event: SessionSyncEvent

    init(id: UUID = UUID(), sentAt: Date = .now, event: SessionSyncEvent) {
        self.id = id
        self.sentAt = sentAt
        self.event = event
    }
}
```

- [ ] **Step 5: Write the codec**

Create `Shared/Sync/SessionSyncCoding.swift`:

```swift
import Foundation

enum SyncCodingFailure: Error {
    case payloadMissingEnvelope
}

/// Bridges envelopes to the `[String: Any]` dictionaries WatchConnectivity accepts,
/// keeping the whole envelope in one `Data` value so plist type limits never apply.
enum SessionSyncCoding {
    static let envelopeKey = "envelope"

    static func messagePayload(for envelope: SyncEnvelope) throws -> [String: Any] {
        [envelopeKey: try JSONEncoder().encode(envelope)]
    }

    static func envelope(from payload: [String: Any]) throws -> SyncEnvelope {
        guard let data = payload[envelopeKey] as? Data else {
            throw SyncCodingFailure.payloadMissingEnvelope
        }
        return try JSONDecoder().decode(SyncEnvelope.self, from: data)
    }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run the global iOS test command. Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Shared/Sync BoulderTrackerTests/SessionSyncCodingTests.swift
git commit -m "feat: add session sync event model and WatchConnectivity codec"
```

---

### Task 3: Model changes for sync identity and heart rate

**Files:**
- Modify: `BoulderTracker/Models/Session.swift`
- Modify: `BoulderTracker/Models/SessionProblem.swift`
- Test: `BoulderTrackerTests/ModelRoundTripTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `Session.syncID: UUID?`, `Session.avgHeartRate/maxHeartRate/activeCalories: Double?`, `Session.isWatchTracked: Bool`, `Session.appliedEventIDs: [UUID]`, `SessionProblem.syncID: UUID?`. Tasks 4, 7, 8 read and write these.

- [ ] **Step 1: Write the failing test**

Append to the `ModelRoundTripTests` struct in `BoulderTrackerTests/ModelRoundTripTests.swift`:

```swift
    @Test func newSessionsAndProblemsGetSyncIdentities() throws {
        let session = Session(startTime: .now, gym: nil, partners: [])
        let problem = SessionProblem(name: "", colorGrade: .blue, styles: [])

        #expect(session.syncID != nil)
        #expect(problem.syncID != nil)
        #expect(session.syncID != problem.syncID)
        #expect(!session.isWatchTracked)
        #expect(session.appliedEventIDs.isEmpty)
    }

    @Test func heartRateSummaryRoundTrips() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let session = Session(startTime: .now, gym: nil, partners: [])
        session.avgHeartRate = 138
        session.maxHeartRate = 176
        session.activeCalories = 512
        session.isWatchTracked = true
        session.appliedEventIDs = [UUID()]
        context.insert(session)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Session>()).first
        #expect(fetched?.avgHeartRate == 138)
        #expect(fetched?.maxHeartRate == 176)
        #expect(fetched?.activeCalories == 512)
        #expect(fetched?.isWatchTracked == true)
        #expect(fetched?.appliedEventIDs.count == 1)
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run the global iOS test command.
Expected: compile FAIL — `value of type 'Session' has no member 'syncID'`.

- [ ] **Step 3: Add the Session properties**

In `BoulderTracker/Models/Session.swift`, add these stored properties after `healthKitWorkoutID`:

```swift
    /// Stable identity across devices. SwiftData's `PersistentIdentifier` is
    /// device-local, so sync needs its own key. Optional because rows migrated
    /// from before sync existed must stay unmatched rather than share a default.
    var syncID: UUID?
    var avgHeartRate: Double?
    var maxHeartRate: Double?
    var activeCalories: Double?
    /// True once any event from the watch touched this session; the phone then
    /// leaves the Health workout to the watch.
    var isWatchTracked: Bool = false
    /// Envelope ids already applied, making replayed deliveries no-ops.
    var appliedEventIDs: [UUID] = []
```

In `init`, after `self.problems = []`, add:

```swift
        self.syncID = UUID()
```

- [ ] **Step 4: Add the SessionProblem property**

In `BoulderTracker/Models/SessionProblem.swift`, add after `isProject`:

```swift
    /// Stable identity across devices; see the note on `Session.syncID`.
    var syncID: UUID?
```

In `init`, after `self.isProject = isProject`, add:

```swift
        self.syncID = UUID()
```

- [ ] **Step 5: Run tests to verify they pass**

Run the global iOS test command. Expected: PASS, including the pre-existing round-trip and cascade tests.

- [ ] **Step 6: Commit**

```bash
git add BoulderTracker/Models BoulderTrackerTests/ModelRoundTripTests.swift
git commit -m "feat: add sync identity and heart rate fields to session models"
```

---

### Task 4: Session sync inbox

**Files:**
- Create: `BoulderTracker/Services/SessionSyncInbox.swift`
- Test: `BoulderTrackerTests/SessionSyncInboxTests.swift`

**Interfaces:**
- Consumes: Task 2's events and envelope; Task 3's model properties.
- Produces: `@MainActor final class SessionSyncInbox`, `init(context: ModelContext)`, `func apply(_ envelope: SyncEnvelope)`. Task 7 owns an instance and feeds it inbound envelopes.

Lives in the app target, not `Shared/`, because it imports SwiftData.

- [ ] **Step 1: Write the failing test**

Create `BoulderTrackerTests/SessionSyncInboxTests.swift`:

```swift
import Testing
import Foundation
import SwiftData
@testable import BoulderTracker

@MainActor
struct SessionSyncInboxTests {
    private let sessionSyncID = UUID()
    private let problemSyncID = UUID()

    private func startEvent(gymName: String? = nil) -> SessionSyncEvent {
        .sessionStarted(SessionStartPayload(
            sessionSyncID: sessionSyncID, startTime: Date(timeIntervalSince1970: 1000),
            gymName: gymName, climbType: .bouldering
        ))
    }

    private func attemptEvent(_ result: AttemptResult) -> SessionSyncEvent {
        .attemptLogged(AttemptLogPayload(
            sessionSyncID: sessionSyncID, problemSyncID: problemSyncID,
            colorGrade: .red, result: result, loggedAt: Date(timeIntervalSince1970: 1100)
        ))
    }

    private func sessions(in context: ModelContext) throws -> [Session] {
        try context.fetch(FetchDescriptor<Session>())
    }

    @Test func sessionStartedCreatesWatchTrackedSession() throws {
        let context = try makeInMemoryContainer().mainContext
        let inbox = SessionSyncInbox(context: context)

        inbox.apply(SyncEnvelope(event: startEvent()))

        let stored = try sessions(in: context)
        #expect(stored.count == 1)
        #expect(stored.first?.syncID == sessionSyncID)
        #expect(stored.first?.isWatchTracked == true)
        #expect(stored.first?.isLive == true)
    }

    @Test func sessionStartedLinksExistingGymByName() throws {
        let context = try makeInMemoryContainer().mainContext
        context.insert(Gym(name: "Klättervigören Jönköping", isDefault: true))
        try context.save()
        let inbox = SessionSyncInbox(context: context)

        inbox.apply(SyncEnvelope(event: startEvent(gymName: "Klättervigören Jönköping")))

        #expect(try sessions(in: context).first?.gym?.name == "Klättervigören Jönköping")
    }

    @Test func replayingSessionStartedDoesNotDuplicate() throws {
        let context = try makeInMemoryContainer().mainContext
        let inbox = SessionSyncInbox(context: context)
        let envelope = SyncEnvelope(event: startEvent())

        inbox.apply(envelope)
        inbox.apply(envelope)

        #expect(try sessions(in: context).count == 1)
    }

    @Test func attemptCreatesProblemFromCarriedGrade() throws {
        let context = try makeInMemoryContainer().mainContext
        let inbox = SessionSyncInbox(context: context)
        inbox.apply(SyncEnvelope(event: startEvent()))

        inbox.apply(SyncEnvelope(event: attemptEvent(.flash)))

        let problems = try sessions(in: context).first?.problems ?? []
        #expect(problems.count == 1)
        #expect(problems.first?.colorGrade == .red)
        #expect(problems.first?.flashCount == 1)
        #expect(problems.first?.syncID == problemSyncID)
    }

    @Test func replayingAttemptCountsOnce() throws {
        let context = try makeInMemoryContainer().mainContext
        let inbox = SessionSyncInbox(context: context)
        inbox.apply(SyncEnvelope(event: startEvent()))
        let envelope = SyncEnvelope(event: attemptEvent(.send))

        inbox.apply(envelope)
        inbox.apply(envelope)
        inbox.apply(envelope)

        #expect(try sessions(in: context).first?.problems.first?.sendCount == 1)
    }

    @Test func distinctAttemptsAccumulateOnOneProblem() throws {
        let context = try makeInMemoryContainer().mainContext
        let inbox = SessionSyncInbox(context: context)
        inbox.apply(SyncEnvelope(event: startEvent()))

        inbox.apply(SyncEnvelope(event: attemptEvent(.fall)))
        inbox.apply(SyncEnvelope(event: attemptEvent(.fall)))
        inbox.apply(SyncEnvelope(event: attemptEvent(.send)))

        let problems = try sessions(in: context).first?.problems ?? []
        #expect(problems.count == 1)
        #expect(problems.first?.fallCount == 2)
        #expect(problems.first?.sendCount == 1)
    }

    @Test func attemptArrivingBeforeSessionReplaysOnceSessionArrives() throws {
        let context = try makeInMemoryContainer().mainContext
        let inbox = SessionSyncInbox(context: context)

        inbox.apply(SyncEnvelope(event: attemptEvent(.flash)))
        #expect(try sessions(in: context).isEmpty)

        inbox.apply(SyncEnvelope(event: startEvent()))

        #expect(try sessions(in: context).first?.problems.first?.flashCount == 1)
    }

    @Test func sessionEndedSetsEndTime() throws {
        let context = try makeInMemoryContainer().mainContext
        let inbox = SessionSyncInbox(context: context)
        inbox.apply(SyncEnvelope(event: startEvent()))
        let endTime = Date(timeIntervalSince1970: 5000)

        inbox.apply(SyncEnvelope(event: .sessionEnded(
            SessionEndPayload(sessionSyncID: sessionSyncID, endTime: endTime)
        )))

        #expect(try sessions(in: context).first?.endTime == endTime)
    }

    @Test func workoutRecordedStoresIDAndHeartRate() throws {
        let context = try makeInMemoryContainer().mainContext
        let inbox = SessionSyncInbox(context: context)
        inbox.apply(SyncEnvelope(event: startEvent()))
        let workoutID = UUID()

        inbox.apply(SyncEnvelope(event: .workoutRecorded(WorkoutSummaryPayload(
            sessionSyncID: sessionSyncID, workoutID: workoutID,
            avgHeartRate: 141, maxHeartRate: 178, activeCalories: 505
        ))))

        let stored = try sessions(in: context).first
        #expect(stored?.healthKitWorkoutID == workoutID)
        #expect(stored?.avgHeartRate == 141)
        #expect(stored?.maxHeartRate == 178)
        #expect(stored?.activeCalories == 505)
    }

    @Test func unknownSessionEndIsIgnored() throws {
        let context = try makeInMemoryContainer().mainContext
        let inbox = SessionSyncInbox(context: context)

        inbox.apply(SyncEnvelope(event: .sessionEnded(
            SessionEndPayload(sessionSyncID: UUID(), endTime: .now)
        )))

        #expect(try sessions(in: context).isEmpty)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run the global iOS test command.
Expected: compile FAIL — `cannot find 'SessionSyncInbox' in scope`.

- [ ] **Step 3: Write the inbox**

Create `BoulderTracker/Services/SessionSyncInbox.swift`:

```swift
import Foundation
import SwiftData

/// Applies sync events from the watch into the phone's store. Every event is
/// idempotent: replaying an envelope leaves the store unchanged. Events that name
/// an unknown session are buffered and replayed when that session arrives.
@MainActor
final class SessionSyncInbox {
    private let context: ModelContext
    private var orphansBySession: [UUID: [SyncEnvelope]] = [:]

    init(context: ModelContext) {
        self.context = context
    }

    func apply(_ envelope: SyncEnvelope) {
        switch envelope.event {
        case .sessionStarted(let payload):
            adoptSession(payload)
        case .attemptLogged(let payload):
            recordAttempt(payload, from: envelope)
        case .sessionEnded(let payload):
            closeSession(payload)
        case .workoutRecorded(let payload):
            attachWorkout(payload)
        case .liveSessionRequest, .sessionSnapshot, .phoneCatalog:
            // Answered by PhoneSyncCoordinator or consumed only on the watch.
            break
        }
        try? context.save()
    }

    private func adoptSession(_ payload: SessionStartPayload) {
        guard session(with: payload.sessionSyncID) == nil else { return }
        let session = Session(
            startTime: payload.startTime,
            gym: gym(named: payload.gymName),
            partners: [],
            climbType: payload.climbType
        )
        session.syncID = payload.sessionSyncID
        session.isWatchTracked = true
        context.insert(session)
        replayOrphans(of: payload.sessionSyncID)
    }

    private func recordAttempt(_ payload: AttemptLogPayload, from envelope: SyncEnvelope) {
        guard let session = session(with: payload.sessionSyncID) else {
            orphansBySession[payload.sessionSyncID, default: []].append(envelope)
            return
        }
        guard !session.appliedEventIDs.contains(envelope.id) else { return }
        let problem = session.problems.first { $0.syncID == payload.problemSyncID }
            ?? insertProblem(payload, into: session)
        problem.recordResult(payload.result)
        session.appliedEventIDs.append(envelope.id)
        session.isWatchTracked = true
    }

    private func closeSession(_ payload: SessionEndPayload) {
        guard let session = session(with: payload.sessionSyncID) else { return }
        session.endTime = payload.endTime
    }

    private func attachWorkout(_ payload: WorkoutSummaryPayload) {
        guard let session = session(with: payload.sessionSyncID) else { return }
        session.healthKitWorkoutID = payload.workoutID
        session.avgHeartRate = payload.avgHeartRate
        session.maxHeartRate = payload.maxHeartRate
        session.activeCalories = payload.activeCalories
        session.isWatchTracked = true
    }

    private func replayOrphans(of sessionSyncID: UUID) {
        let buffered = orphansBySession.removeValue(forKey: sessionSyncID) ?? []
        for envelope in buffered {
            guard case .attemptLogged(let payload) = envelope.event else { continue }
            recordAttempt(payload, from: envelope)
        }
    }

    private func insertProblem(
        _ payload: AttemptLogPayload, into session: Session
    ) -> SessionProblem {
        let problem = SessionProblem(name: "", colorGrade: payload.colorGrade, styles: [])
        problem.syncID = payload.problemSyncID
        session.problems.append(problem)
        return problem
    }

    private func session(with syncID: UUID) -> Session? {
        let wanted: UUID? = syncID
        let descriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.syncID == wanted })
        return try? context.fetch(descriptor).first
    }

    private func gym(named name: String?) -> Gym? {
        guard let name else { return nil }
        let descriptor = FetchDescriptor<Gym>(predicate: #Predicate { $0.name == name })
        return try? context.fetch(descriptor).first
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run the global iOS test command. Expected: PASS.

If `#Predicate { $0.syncID == wanted }` fails to compile, fetch all sessions and filter in Swift instead — the store holds tens of sessions, so the cost is irrelevant:

```swift
    private func session(with syncID: UUID) -> Session? {
        let all = (try? context.fetch(FetchDescriptor<Session>())) ?? []
        return all.first { $0.syncID == syncID }
    }
```

- [ ] **Step 5: Commit**

```bash
git add BoulderTracker/Services/SessionSyncInbox.swift BoulderTrackerTests/SessionSyncInboxTests.swift
git commit -m "feat: add idempotent session sync inbox"
```

---

### Task 5: Durable pending event queue

**Files:**
- Create: `Shared/Sync/PendingEventQueue.swift`
- Test: `BoulderTrackerTests/PendingEventQueueTests.swift`

**Interfaces:**
- Consumes: Task 2's `SyncEnvelope`.
- Produces: `final class PendingEventQueue`, `init(fileURL: URL)`, `static func inApplicationSupport(named:) -> PendingEventQueue`, `var pending: [SyncEnvelope]`, `func append(_:)`, `func remove(deliveredID:)`. Task 6's outbox owns one.

- [ ] **Step 1: Write the failing test**

Create `BoulderTrackerTests/PendingEventQueueTests.swift`:

```swift
import Testing
import Foundation
@testable import BoulderTracker

struct PendingEventQueueTests {
    private func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("queue-\(UUID().uuidString).json")
    }

    private func endedEvent() -> SessionSyncEvent {
        .sessionEnded(SessionEndPayload(sessionSyncID: UUID(), endTime: .now))
    }

    @Test func newQueueIsEmpty() {
        #expect(PendingEventQueue(fileURL: temporaryFileURL()).pending.isEmpty)
    }

    @Test func appendedEnvelopesArePending() {
        let queue = PendingEventQueue(fileURL: temporaryFileURL())
        let envelope = SyncEnvelope(event: endedEvent())

        queue.append(envelope)

        #expect(queue.pending.map(\.id) == [envelope.id])
    }

    @Test func removingDeliveredEnvelopeDropsIt() {
        let queue = PendingEventQueue(fileURL: temporaryFileURL())
        let first = SyncEnvelope(event: endedEvent())
        let second = SyncEnvelope(event: endedEvent())
        queue.append(first)
        queue.append(second)

        queue.remove(deliveredID: first.id)

        #expect(queue.pending.map(\.id) == [second.id])
    }

    @Test func pendingEnvelopesSurviveANewInstance() {
        let fileURL = temporaryFileURL()
        let envelope = SyncEnvelope(event: endedEvent())
        PendingEventQueue(fileURL: fileURL).append(envelope)

        let reopened = PendingEventQueue(fileURL: fileURL)

        #expect(reopened.pending.map(\.id) == [envelope.id])
    }

    @Test func removalSurvivesANewInstance() {
        let fileURL = temporaryFileURL()
        let queue = PendingEventQueue(fileURL: fileURL)
        let envelope = SyncEnvelope(event: endedEvent())
        queue.append(envelope)
        queue.remove(deliveredID: envelope.id)

        #expect(PendingEventQueue(fileURL: fileURL).pending.isEmpty)
    }

    @Test func corruptFileYieldsEmptyQueue() throws {
        let fileURL = temporaryFileURL()
        try Data("not json".utf8).write(to: fileURL)

        #expect(PendingEventQueue(fileURL: fileURL).pending.isEmpty)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run the global iOS test command.
Expected: compile FAIL — `cannot find 'PendingEventQueue' in scope`.

- [ ] **Step 3: Write the queue**

Create `Shared/Sync/PendingEventQueue.swift`:

```swift
import Foundation

/// Outbound envelopes held on disk until the peer confirms delivery, so a session
/// logged with the phone out of range survives the app being terminated.
final class PendingEventQueue {
    private let fileURL: URL
    private var envelopes: [SyncEnvelope]

    init(fileURL: URL) {
        self.fileURL = fileURL
        self.envelopes = Self.storedEnvelopes(at: fileURL)
    }

    var pending: [SyncEnvelope] { envelopes }

    func append(_ envelope: SyncEnvelope) {
        envelopes.append(envelope)
        persist()
    }

    func remove(deliveredID: UUID) {
        envelopes.removeAll { $0.id == deliveredID }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(envelopes) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func storedEnvelopes(at fileURL: URL) -> [SyncEnvelope] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([SyncEnvelope].self, from: data)) ?? []
    }
}

extension PendingEventQueue {
    static func inApplicationSupport(named filename: String) -> PendingEventQueue {
        let directory = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0]
        try? FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true
        )
        return PendingEventQueue(fileURL: directory.appendingPathComponent(filename))
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run the global iOS test command. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Shared/Sync/PendingEventQueue.swift BoulderTrackerTests/PendingEventQueueTests.swift
git commit -m "feat: add durable pending event queue for sync delivery"
```

---

### Task 6: Sync link protocol, outbox, and WatchConnectivity implementation

**Files:**
- Create: `Shared/Sync/SyncLinking.swift`
- Create: `Shared/Sync/SessionSyncOutbox.swift`
- Create: `Shared/Sync/WatchConnectivityLink.swift`
- Test: `BoulderTrackerTests/SessionSyncOutboxTests.swift`
- Test: `BoulderTrackerTests/FakeSyncLink.swift`

**Interfaces:**
- Consumes: Tasks 2 and 5.
- Produces: `@MainActor protocol SyncLinking` (`isPeerReachable`, `onDelivered`, `onReceive`, `sendImmediately(_:)`, `transferGuaranteed(_:)`); `@MainActor final class SessionSyncOutbox(queue:link:)` with `send(_ event:)` and `resendPending()`; `@MainActor final class WatchConnectivityLink` with `activate()`. Tasks 7 and 11 own an outbox plus a link.

`WatchConnectivityLink` imports `WatchConnectivity`, which exists on both iOS and watchOS, so it stays in `Shared/`.

- [ ] **Step 1: Write the fake link and the failing test**

Create `BoulderTrackerTests/FakeSyncLink.swift`:

```swift
import Foundation
@testable import BoulderTracker

@MainActor
final class FakeSyncLink: SyncLinking {
    var isPeerReachable = true
    var onDelivered: ((UUID) -> Void)?
    var onReceive: ((SyncEnvelope) -> Void)?
    private(set) var immediate: [SyncEnvelope] = []
    private(set) var guaranteed: [SyncEnvelope] = []

    func sendImmediately(_ envelope: SyncEnvelope) {
        immediate.append(envelope)
    }

    func transferGuaranteed(_ envelope: SyncEnvelope) {
        guaranteed.append(envelope)
    }

    func confirmDelivery(of envelope: SyncEnvelope) {
        onDelivered?(envelope.id)
    }
}
```

Create `BoulderTrackerTests/SessionSyncOutboxTests.swift`:

```swift
import Testing
import Foundation
@testable import BoulderTracker

@MainActor
struct SessionSyncOutboxTests {
    private func temporaryQueue() -> PendingEventQueue {
        PendingEventQueue(fileURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("outbox-\(UUID().uuidString).json"))
    }

    private func endedEvent() -> SessionSyncEvent {
        .sessionEnded(SessionEndPayload(sessionSyncID: UUID(), endTime: .now))
    }

    @Test func reachablePeerGetsBothChannels() {
        let link = FakeSyncLink()
        let outbox = SessionSyncOutbox(queue: temporaryQueue(), link: link)

        outbox.send(endedEvent())

        #expect(link.immediate.count == 1)
        #expect(link.guaranteed.count == 1)
        #expect(link.immediate.first?.id == link.guaranteed.first?.id)
    }

    @Test func unreachablePeerGetsOnlyGuaranteedChannel() {
        let link = FakeSyncLink()
        link.isPeerReachable = false
        let outbox = SessionSyncOutbox(queue: temporaryQueue(), link: link)

        outbox.send(endedEvent())

        #expect(link.immediate.isEmpty)
        #expect(link.guaranteed.count == 1)
    }

    @Test func sentEventStaysPendingUntilDeliveryIsConfirmed() {
        let queue = temporaryQueue()
        let link = FakeSyncLink()
        let outbox = SessionSyncOutbox(queue: queue, link: link)

        outbox.send(endedEvent())
        #expect(queue.pending.count == 1)

        link.confirmDelivery(of: link.guaranteed[0])
        #expect(queue.pending.isEmpty)
    }

    @Test func resendPendingRedeliversEverythingUnconfirmed() {
        let queue = temporaryQueue()
        let link = FakeSyncLink()
        let outbox = SessionSyncOutbox(queue: queue, link: link)
        outbox.send(endedEvent())
        outbox.send(endedEvent())

        outbox.resendPending()

        #expect(link.guaranteed.count == 4)
        #expect(queue.pending.count == 2)
    }

    @Test func resendKeepsEnvelopeIdentitiesStable() {
        let queue = temporaryQueue()
        let link = FakeSyncLink()
        let outbox = SessionSyncOutbox(queue: queue, link: link)
        outbox.send(endedEvent())
        let originalID = link.guaranteed[0].id

        outbox.resendPending()

        #expect(link.guaranteed[1].id == originalID)
    }
}
```

The last test matters: resending must reuse the envelope id, otherwise the receiver's de-duplication cannot recognise the duplicate and every reconnect would double-count logs.

- [ ] **Step 2: Run test to verify it fails**

Run the global iOS test command.
Expected: compile FAIL — `cannot find type 'SyncLinking' in scope`.

- [ ] **Step 3: Write the link protocol**

Create `Shared/Sync/SyncLinking.swift`:

```swift
import Foundation

/// The transport seam. `WatchConnectivityLink` is the only production conformer;
/// tests drive the outbox through a fake.
@MainActor
protocol SyncLinking: AnyObject {
    /// True when the peer can receive a low-latency message right now.
    var isPeerReachable: Bool { get }
    /// Called with an envelope id once guaranteed delivery has completed.
    var onDelivered: ((UUID) -> Void)? { get set }
    /// Called for every envelope arriving from the peer, duplicates included.
    var onReceive: ((SyncEnvelope) -> Void)? { get set }

    func sendImmediately(_ envelope: SyncEnvelope)
    func transferGuaranteed(_ envelope: SyncEnvelope)
}
```

- [ ] **Step 4: Write the outbox**

Create `Shared/Sync/SessionSyncOutbox.swift`:

```swift
import Foundation

/// Sends events over both WatchConnectivity channels and keeps them queued until
/// the guaranteed channel confirms delivery. Duplicate arrival is harmless because
/// receivers de-duplicate on envelope id.
@MainActor
final class SessionSyncOutbox {
    private let queue: PendingEventQueue
    private let link: SyncLinking

    init(queue: PendingEventQueue, link: SyncLinking) {
        self.queue = queue
        self.link = link
        link.onDelivered = { [weak queue] deliveredID in
            queue?.remove(deliveredID: deliveredID)
        }
    }

    func send(_ event: SessionSyncEvent) {
        let envelope = SyncEnvelope(event: event)
        queue.append(envelope)
        deliver(envelope)
    }

    func resendPending() {
        for envelope in queue.pending {
            deliver(envelope)
        }
    }

    private func deliver(_ envelope: SyncEnvelope) {
        if link.isPeerReachable {
            link.sendImmediately(envelope)
        }
        link.transferGuaranteed(envelope)
    }
}
```

- [ ] **Step 5: Write the WatchConnectivity link**

Create `Shared/Sync/WatchConnectivityLink.swift`:

```swift
import Foundation
import WatchConnectivity

/// Wraps `WCSession`. Every envelope goes out on both channels: `sendMessage` for
/// the live mirror when the peer is awake, `transferUserInfo` for guaranteed FIFO
/// delivery that survives termination and out-of-range periods.
@MainActor
final class WatchConnectivityLink: NSObject, SyncLinking {
    var onDelivered: ((UUID) -> Void)?
    var onReceive: ((SyncEnvelope) -> Void)?

    private let session = WCSession.default
    private var envelopeIDsByTransfer: [ObjectIdentifier: UUID] = [:]

    var isPeerReachable: Bool {
        WCSession.isSupported() && session.isReachable
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
    }

    func sendImmediately(_ envelope: SyncEnvelope) {
        guard let payload = try? SessionSyncCoding.messagePayload(for: envelope) else { return }
        session.sendMessage(payload, replyHandler: nil) { _ in
            // Guaranteed channel still carries this envelope; nothing to recover.
        }
    }

    func transferGuaranteed(_ envelope: SyncEnvelope) {
        guard let payload = try? SessionSyncCoding.messagePayload(for: envelope) else { return }
        let transfer = session.transferUserInfo(payload)
        envelopeIDsByTransfer[ObjectIdentifier(transfer)] = envelope.id
    }

    fileprivate func receive(_ payload: [String: Any]) {
        guard let envelope = try? SessionSyncCoding.envelope(from: payload) else { return }
        onReceive?(envelope)
    }

    fileprivate func completeTransfer(_ transfer: WCSessionUserInfoTransfer, error: Error?) {
        let key = ObjectIdentifier(transfer)
        guard error == nil, let envelopeID = envelopeIDsByTransfer.removeValue(forKey: key) else {
            return
        }
        onDelivered?(envelopeID)
    }
}

extension WatchConnectivityLink: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession, activationDidCompleteWith state: WCSessionActivationState,
        error: Error?
    ) {}

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        Task { @MainActor in self.receive(userInfo) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in self.receive(message) }
    }

    nonisolated func session(
        _ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer,
        error: Error?
    ) {
        Task { @MainActor in self.completeTransfer(userInfoTransfer, error: error) }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run the global iOS test command. Expected: PASS.

Then the watch build command. Expected: build succeeds — this is the first shared file importing `WatchConnectivity`, so it proves the framework links on watchOS.

If Swift 6 rejects `session.delegate = self` because `WCSessionDelegate` is not main-actor isolated, mark the conformance methods as shown (they already are `nonisolated`) and, if the assignment itself is still rejected, wrap the class in `@preconcurrency` on the extension: `extension WatchConnectivityLink: @preconcurrency WCSessionDelegate`.

If `didFinish userInfoTransfer` fires on a transfer this link never registered (possible after a relaunch with queued transfers), `completeTransfer` returns without calling back — the envelope stays queued and is resent, which the receiver de-duplicates. That is the intended behaviour, not a leak.

- [ ] **Step 7: Commit**

```bash
git add Shared/Sync BoulderTrackerTests/FakeSyncLink.swift BoulderTrackerTests/SessionSyncOutboxTests.swift
git commit -m "feat: add sync transport protocol, outbox, and WatchConnectivity link"
```

---

### Task 7: Phone sync coordinator

**Files:**
- Create: `BoulderTracker/Services/LiveSessionSnapshotReader.swift`
- Create: `BoulderTracker/Services/PhoneSyncCoordinator.swift`
- Modify: `BoulderTracker/App/BoulderTrackerApp.swift`
- Modify: `BoulderTracker/Home/GymPickerSheet.swift`
- Modify: `BoulderTracker/Home/QuickLogRow.swift`
- Modify: `BoulderTracker/Home/ProblemTile.swift`
- Modify: `BoulderTracker/Home/LiveSessionView.swift`
- Test: `BoulderTrackerTests/LiveSessionSnapshotReaderTests.swift`

**Interfaces:**
- Consumes: Tasks 2–6.
- Produces: `enum LiveSessionSnapshotReader` with `static func snapshot(of session: Session?) -> LiveSessionSnapshot?`; `@MainActor @Observable final class PhoneSyncCoordinator(context:)` with `start()`, `announceStart(of:)`, `announceAttempt(on:in:result:)`, `announceEnd(of:)`. The coordinator is injected through `.environment(...)` and read with `@Environment(PhoneSyncCoordinator.self)`.

- [ ] **Step 1: Write the failing test**

Create `BoulderTrackerTests/LiveSessionSnapshotReaderTests.swift`:

```swift
import Testing
import Foundation
@testable import BoulderTracker

@MainActor
struct LiveSessionSnapshotReaderTests {
    @Test func noSessionYieldsNoSnapshot() {
        #expect(LiveSessionSnapshotReader.snapshot(of: nil) == nil)
    }

    @Test func finishedSessionYieldsNoSnapshot() {
        let session = Session(startTime: .now, gym: nil, partners: [])
        session.endTime = .now

        #expect(LiveSessionSnapshotReader.snapshot(of: session) == nil)
    }

    @Test func liveSessionCarriesGymClimbTypeAndCounts() {
        let gym = Gym(name: "Klättervigören Jönköping", isDefault: true)
        let session = Session(
            startTime: Date(timeIntervalSince1970: 900), gym: gym,
            partners: [], climbType: .lead
        )
        let problem = SessionProblem(
            name: "", colorGrade: .black, styles: [],
            flashCount: 1, sendCount: 2, fallCount: 3
        )
        session.problems.append(problem)

        let snapshot = LiveSessionSnapshotReader.snapshot(of: session)

        #expect(snapshot?.sessionSyncID == session.syncID)
        #expect(snapshot?.startTime == Date(timeIntervalSince1970: 900))
        #expect(snapshot?.gymName == "Klättervigören Jönköping")
        #expect(snapshot?.climbType == .lead)
        #expect(snapshot?.problems.count == 1)
        #expect(snapshot?.problems.first?.colorGrade == .black)
        #expect(snapshot?.problems.first?.flashCount == 1)
        #expect(snapshot?.problems.first?.sendCount == 2)
        #expect(snapshot?.problems.first?.fallCount == 3)
    }

    @Test func problemsWithoutSyncIDsAreOmitted() {
        let session = Session(startTime: .now, gym: nil, partners: [])
        let problem = SessionProblem(name: "", colorGrade: .green, styles: [], sendCount: 1)
        problem.syncID = nil
        session.problems.append(problem)

        #expect(LiveSessionSnapshotReader.snapshot(of: session)?.problems.isEmpty == true)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run the global iOS test command.
Expected: compile FAIL — `cannot find 'LiveSessionSnapshotReader' in scope`.

- [ ] **Step 3: Write the snapshot reader**

Create `BoulderTracker/Services/LiveSessionSnapshotReader.swift`:

```swift
import Foundation

/// Builds the absolute-state snapshot used only for watch cold-start catch-up.
/// A session that predates sync has no `syncID` and cannot be mirrored.
enum LiveSessionSnapshotReader {
    static func snapshot(of session: Session?) -> LiveSessionSnapshot? {
        guard let session, session.isLive, let sessionSyncID = session.syncID else { return nil }
        return LiveSessionSnapshot(
            sessionSyncID: sessionSyncID,
            startTime: session.startTime,
            gymName: session.gym?.name,
            climbType: session.climbType,
            problems: session.problems.compactMap(counts(of:))
        )
    }

    private static func counts(of problem: SessionProblem) -> ProblemCountsSnapshot? {
        guard let problemSyncID = problem.syncID else { return nil }
        return ProblemCountsSnapshot(
            problemSyncID: problemSyncID,
            colorGrade: problem.colorGrade,
            flashCount: problem.flashCount,
            sendCount: problem.sendCount,
            fallCount: problem.fallCount
        )
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run the global iOS test command. Expected: PASS.

- [ ] **Step 5: Write the coordinator**

Create `BoulderTracker/Services/PhoneSyncCoordinator.swift`:

```swift
import Foundation
import SwiftData
import SwiftUI

/// Owns the phone side of the watch link: routes inbound events to the inbox,
/// answers the watch's cold-start request, and publishes phone-side logging so the
/// watch tally stays in step.
@MainActor
@Observable
final class PhoneSyncCoordinator {
    private let context: ModelContext
    private let inbox: SessionSyncInbox
    private let outbox: SessionSyncOutbox
    private let link: WatchConnectivityLink

    init(context: ModelContext) {
        self.context = context
        self.inbox = SessionSyncInbox(context: context)
        self.link = WatchConnectivityLink()
        self.outbox = SessionSyncOutbox(
            queue: .inApplicationSupport(named: "phone-sync-queue.json"), link: link
        )
    }

    func start() {
        link.onReceive = { [weak self] envelope in self?.route(envelope) }
        link.activate()
        outbox.resendPending()
        sendCatalog()
    }

    func announceStart(of session: Session) {
        guard let sessionSyncID = session.syncID else { return }
        outbox.send(.sessionStarted(SessionStartPayload(
            sessionSyncID: sessionSyncID,
            startTime: session.startTime,
            gymName: session.gym?.name,
            climbType: session.climbType
        )))
    }

    func announceAttempt(
        on problem: SessionProblem, in session: Session, result: AttemptResult
    ) {
        guard let sessionSyncID = session.syncID, let problemSyncID = problem.syncID else {
            return
        }
        outbox.send(.attemptLogged(AttemptLogPayload(
            sessionSyncID: sessionSyncID,
            problemSyncID: problemSyncID,
            colorGrade: problem.colorGrade,
            result: result,
            loggedAt: .now
        )))
    }

    func announceEnd(of session: Session) {
        guard let sessionSyncID = session.syncID, let endTime = session.endTime else { return }
        outbox.send(.sessionEnded(SessionEndPayload(
            sessionSyncID: sessionSyncID, endTime: endTime
        )))
    }

    private func route(_ envelope: SyncEnvelope) {
        if case .liveSessionRequest = envelope.event {
            answerLiveSessionRequest()
            return
        }
        inbox.apply(envelope)
    }

    private func answerLiveSessionRequest() {
        let live = (try? context.fetch(FetchDescriptor<Session>()))?.first { $0.isLive }
        outbox.send(.sessionSnapshot(SessionSnapshotPayload(
            liveSession: LiveSessionSnapshotReader.snapshot(of: live)
        )))
        sendCatalog()
    }

    private func sendCatalog() {
        let gyms = (try? context.fetch(FetchDescriptor<Gym>())) ?? []
        let healthKitSyncEnabled = UserDefaults.standard
            .object(forKey: AppPreferences.healthKitSyncKey) as? Bool ?? true
        outbox.send(.phoneCatalog(PhoneCatalogPayload(
            gyms: gyms.map { GymSnapshot(name: $0.name, isDefault: $0.isDefault) },
            healthKitSyncEnabled: healthKitSyncEnabled
        )))
    }
}
```

- [ ] **Step 6: Inject the coordinator into the app**

In `BoulderTracker/App/BoulderTrackerApp.swift`, add a stored property and build it after the container:

```swift
    let container: ModelContainer
    private let syncCoordinator: PhoneSyncCoordinator
```

At the end of `init()`, after the `do/catch` block:

```swift
        syncCoordinator = PhoneSyncCoordinator(context: container.mainContext)
```

Note `container` is assigned inside the `do` block, so this line must come after it. `PhoneSyncCoordinator` is `@MainActor`; `BoulderTrackerApp.init` already runs on the main actor as a SwiftUI `App`, so no annotation is needed.

Change the scene body to inject and start it:

```swift
    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(syncCoordinator)
                .task { syncCoordinator.start() }
        }
        .modelContainer(container)
    }
```

- [ ] **Step 7: Emit events from the four phone logging sites**

In `BoulderTracker/Home/GymPickerSheet.swift`, add the environment read next to the existing ones:

```swift
    @Environment(PhoneSyncCoordinator.self) private var syncCoordinator
```

and in `startSession(at:)`, after `try? modelContext.save()`:

```swift
        syncCoordinator.announceStart(of: session)
```

In `BoulderTracker/Home/QuickLogRow.swift`, add the same environment read, and in `log(grade:result:)` after `try? modelContext.save()`:

```swift
        syncCoordinator.announceAttempt(on: problem, in: session, result: result)
```

In `BoulderTracker/Home/ProblemTile.swift`, add the same environment read. The tile has a `problem` but no `session`; use `problem.session`. At line 94, replace:

```swift
            problem.recordResult(result)
```

with:

```swift
            problem.recordResult(result)
            if let session = problem.session {
                syncCoordinator.announceAttempt(on: problem, in: session, result: result)
            }
```

Keep the existing `try? modelContext.save()` that follows.

In `BoulderTracker/Home/LiveSessionView.swift`, add the same environment read, and in `endSession()` after `try? modelContext.save()`:

```swift
        syncCoordinator.announceEnd(of: session)
```

- [ ] **Step 8: Run the full suite**

Run the global iOS test command. Expected: PASS.

SwiftUI previews and tests that instantiate these views without the environment value will trap at runtime. There are no such previews or view tests in this repo — if the build surfaces one, give it `.environment(PhoneSyncCoordinator(context:))` over an in-memory container.

- [ ] **Step 9: Commit**

```bash
git add BoulderTracker BoulderTrackerTests/LiveSessionSnapshotReaderTests.swift
git commit -m "feat: publish phone session events to the watch"
```

---

### Task 8: Defer the Health workout to the watch and show heart rate

**Files:**
- Modify: `BoulderTracker/Services/SessionCompletionOutcome.swift`
- Modify: `BoulderTracker/Services/SessionCompletion.swift`
- Modify: `BoulderTracker/Home/SessionSummaryScreen.swift`
- Test: `BoulderTrackerTests/SessionCompletionTests.swift`

**Interfaces:**
- Consumes: Task 3's `isWatchTracked`, `avgHeartRate`, `maxHeartRate`.
- Produces: `WorkoutSaveResult.recordedByWatch`.

- [ ] **Step 1: Write the failing test**

Append to the `SessionCompletionTests` struct in `BoulderTrackerTests/SessionCompletionTests.swift`:

```swift
    @Test func watchTrackedSessionSkipsPhoneWorkoutWrite() async {
        let writer = FakeWorkoutWriter()
        let completion = SessionCompletion(workoutWriter: writer)
        let session = Session(startTime: .now.addingTimeInterval(-3600), gym: nil, partners: [])
        session.isWatchTracked = true

        let outcome = await completion.finish(
            session, endTime: .now, allSessions: [session], unlockedIDs: []
        )

        #expect(session.endTime != nil)
        #expect(outcome.workoutSave == .recordedByWatch)
        #expect(writer.savedIntervals.isEmpty)
    }

    @Test func watchTrackedSessionKeepsWorkoutIDFromTheWatch() async {
        let watchWorkoutID = UUID()
        let completion = SessionCompletion(workoutWriter: FakeWorkoutWriter())
        let session = Session(startTime: .now.addingTimeInterval(-3600), gym: nil, partners: [])
        session.isWatchTracked = true
        session.healthKitWorkoutID = watchWorkoutID

        _ = await completion.finish(
            session, endTime: .now, allSessions: [session], unlockedIDs: []
        )

        #expect(session.healthKitWorkoutID == watchWorkoutID)
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run the global iOS test command.
Expected: FAIL — `type 'WorkoutSaveResult' has no member 'recordedByWatch'`.

- [ ] **Step 3: Add the result case**

In `BoulderTracker/Services/SessionCompletionOutcome.swift`:

```swift
enum WorkoutSaveResult {
    case saved
    case failed
    case syncDisabled
    /// The watch ran the live workout and reported it; the phone must not write a second one.
    case recordedByWatch
}
```

- [ ] **Step 4: Guard the phone's workout write**

In `BoulderTracker/Services/SessionCompletion.swift`, make `saveWorkout(for:)` return early — this must be the first guard, before the `workoutWriter` check, so the case holds whether or not Health sync is on:

```swift
    @MainActor
    private func saveWorkout(for session: Session) async -> WorkoutSaveResult {
        guard !session.isWatchTracked else { return .recordedByWatch }
        guard let workoutWriter else { return .syncDisabled }
        guard let end = session.endTime else { return .failed }
        ...
    }
```

The rest of the method is unchanged.

- [ ] **Step 5: Run tests to verify they pass**

Run the global iOS test command. Expected: PASS, including the three pre-existing `SessionCompletionTests`.

If the compiler reports a non-exhaustive `switch` over `WorkoutSaveResult` anywhere, add a `.recordedByWatch` branch that reads the same as `.saved` — from the user's point of view the workout did get saved.

- [ ] **Step 6: Show the heart-rate summary**

In `BoulderTracker/Home/SessionSummaryScreen.swift`, inside `statsGrid`, add a tile after the existing ones, still inside the `LazyVGrid`:

```swift
            if let avgHeartRate = session.avgHeartRate {
                StatTile(
                    valueText: "\(Int(avgHeartRate.rounded()))",
                    label: "Avg BPM"
                )
            }
            if let maxHeartRate = session.maxHeartRate {
                StatTile(
                    valueText: "\(Int(maxHeartRate.rounded()))",
                    label: "Max BPM"
                )
            }
```

Read `BoulderTracker/Design/StatTile.swift` first and match its actual initialiser — if the labels differ from `valueText:`/`label:`, use the real ones.

- [ ] **Step 7: Run the full suite**

Run the global iOS test command. Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add BoulderTracker BoulderTrackerTests/SessionCompletionTests.swift
git commit -m "feat: defer the Health workout to the watch and show heart rate"
```

---

### Task 9: Watch live session state

**Files:**
- Create: `Shared/Sync/WatchLiveSession.swift`
- Test: `BoulderTrackerTests/WatchLiveSessionTests.swift`

**Interfaces:**
- Consumes: Tasks 2 and 5.
- Produces: `@MainActor @Observable final class WatchLiveSession(fileURL:)` with `snapshot: LiveSessionSnapshot?`, `tally: [(grade: ColorGrade, count: Int)]`, `func apply(_ event: SessionSyncEvent)`, and the event factories `startEvent(gymName:climbType:startTime:)`, `attemptEvent(grade:result:loggedAt:)`, `endEvent(endTime:)`. Task 11's UI reads `snapshot`/`tally` and hands the factories' output to both `apply` and the outbox.

Lives in `Shared/` so the iOS test target can exercise it. Foundation and Observation only.

Commands and queries stay separate: the factories build an event without mutating, `apply` mutates without returning.

- [ ] **Step 1: Write the failing test**

Create `BoulderTrackerTests/WatchLiveSessionTests.swift`:

```swift
import Testing
import Foundation
@testable import BoulderTracker

@MainActor
struct WatchLiveSessionTests {
    private func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("watch-live-\(UUID().uuidString).json")
    }

    private func started(_ live: WatchLiveSession, gymName: String? = "Klättervigören Jönköping") {
        live.apply(live.startEvent(
            gymName: gymName, climbType: .bouldering,
            startTime: Date(timeIntervalSince1970: 100)
        ))
    }

    @Test func newSessionHasNothingLive() {
        #expect(WatchLiveSession(fileURL: temporaryFileURL()).snapshot == nil)
    }

    @Test func startingRecordsGymAndClimbType() {
        let live = WatchLiveSession(fileURL: temporaryFileURL())

        started(live)

        #expect(live.snapshot?.gymName == "Klättervigören Jönköping")
        #expect(live.snapshot?.climbType == .bouldering)
        #expect(live.snapshot?.startTime == Date(timeIntervalSince1970: 100))
        #expect(live.snapshot?.problems.isEmpty == true)
    }

    @Test func loggingAccumulatesOneProblemPerGrade() {
        let live = WatchLiveSession(fileURL: temporaryFileURL())
        started(live)

        live.apply(live.attemptEvent(grade: .red, result: .fall, loggedAt: .now))
        live.apply(live.attemptEvent(grade: .red, result: .send, loggedAt: .now))
        live.apply(live.attemptEvent(grade: .blue, result: .flash, loggedAt: .now))

        #expect(live.snapshot?.problems.count == 2)
        let red = live.snapshot?.problems.first { $0.colorGrade == .red }
        #expect(red?.fallCount == 1)
        #expect(red?.sendCount == 1)
    }

    @Test func tallyCountsEveryLogPerGrade() {
        let live = WatchLiveSession(fileURL: temporaryFileURL())
        started(live)
        live.apply(live.attemptEvent(grade: .red, result: .fall, loggedAt: .now))
        live.apply(live.attemptEvent(grade: .red, result: .send, loggedAt: .now))

        #expect(live.tally.first { $0.grade == .red }?.count == 2)
        #expect(live.tally.contains { $0.grade == .blue } == false)
    }

    @Test func endingClearsTheLiveSession() {
        let live = WatchLiveSession(fileURL: temporaryFileURL())
        started(live)

        live.apply(live.endEvent(endTime: .now))

        #expect(live.snapshot == nil)
    }

    @Test func remoteAttemptFromThePhoneIsMerged() {
        let live = WatchLiveSession(fileURL: temporaryFileURL())
        started(live)
        guard let sessionSyncID = live.snapshot?.sessionSyncID else {
            Issue.record("no live session")
            return
        }

        live.apply(.attemptLogged(AttemptLogPayload(
            sessionSyncID: sessionSyncID, problemSyncID: UUID(), colorGrade: .white,
            result: .send, loggedAt: .now
        )))

        #expect(live.tally.first { $0.grade == .white }?.count == 1)
    }

    @Test func eventsForAnotherSessionAreIgnored() {
        let live = WatchLiveSession(fileURL: temporaryFileURL())
        started(live)

        live.apply(.attemptLogged(AttemptLogPayload(
            sessionSyncID: UUID(), problemSyncID: UUID(), colorGrade: .white,
            result: .send, loggedAt: .now
        )))

        #expect(live.snapshot?.problems.isEmpty == true)
    }

    @Test func snapshotAdoptionFillsAnEmptyWatch() {
        let live = WatchLiveSession(fileURL: temporaryFileURL())
        let adopted = LiveSessionSnapshot(
            sessionSyncID: UUID(), startTime: Date(timeIntervalSince1970: 700),
            gymName: "Elsewhere", climbType: .lead,
            problems: [ProblemCountsSnapshot(
                problemSyncID: UUID(), colorGrade: .green,
                flashCount: 2, sendCount: 0, fallCount: 0
            )]
        )

        live.apply(.sessionSnapshot(SessionSnapshotPayload(liveSession: adopted)))

        #expect(live.snapshot == adopted)
    }

    @Test func snapshotNeverOverwritesAnActiveWatchSession() {
        let live = WatchLiveSession(fileURL: temporaryFileURL())
        started(live)
        let ownID = live.snapshot?.sessionSyncID

        live.apply(.sessionSnapshot(SessionSnapshotPayload(liveSession: LiveSessionSnapshot(
            sessionSyncID: UUID(), startTime: .now, gymName: "Elsewhere",
            climbType: .lead, problems: []
        ))))

        #expect(live.snapshot?.sessionSyncID == ownID)
    }

    @Test func liveSessionSurvivesRelaunch() {
        let fileURL = temporaryFileURL()
        let live = WatchLiveSession(fileURL: fileURL)
        started(live)
        live.apply(live.attemptEvent(grade: .black, result: .flash, loggedAt: .now))

        let reopened = WatchLiveSession(fileURL: fileURL)

        #expect(reopened.snapshot?.sessionSyncID == live.snapshot?.sessionSyncID)
        #expect(reopened.tally.first { $0.grade == .black }?.count == 1)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run the global iOS test command.
Expected: compile FAIL — `cannot find 'WatchLiveSession' in scope`.

- [ ] **Step 3: Write the live session**

Create `Shared/Sync/WatchLiveSession.swift`:

```swift
import Foundation
import Observation

/// The watch's view of the session in progress, persisted so a crash or relaunch
/// mid-session loses nothing. Quick logs collapse onto one problem per grade,
/// matching the phone's `QuickLogRow` behaviour.
@MainActor
@Observable
final class WatchLiveSession {
    private(set) var snapshot: LiveSessionSnapshot?
    @ObservationIgnored private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
        self.snapshot = Self.storedSnapshot(at: fileURL)
    }

    var tally: [(grade: ColorGrade, count: Int)] {
        let problems = snapshot?.problems ?? []
        return ColorGrade.displayOrder.compactMap { grade in
            let count = problems
                .filter { $0.colorGrade == grade }
                .reduce(0) { $0 + $1.flashCount + $1.sendCount + $1.fallCount }
            return count > 0 ? (grade, count) : nil
        }
    }

    func startEvent(
        gymName: String?, climbType: ClimbType, startTime: Date
    ) -> SessionSyncEvent {
        .sessionStarted(SessionStartPayload(
            sessionSyncID: UUID(), startTime: startTime,
            gymName: gymName, climbType: climbType
        ))
    }

    func attemptEvent(
        grade: ColorGrade, result: AttemptResult, loggedAt: Date
    ) -> SessionSyncEvent {
        .attemptLogged(AttemptLogPayload(
            sessionSyncID: snapshot?.sessionSyncID ?? UUID(),
            problemSyncID: problemSyncID(for: grade),
            colorGrade: grade, result: result, loggedAt: loggedAt
        ))
    }

    func endEvent(endTime: Date) -> SessionSyncEvent {
        .sessionEnded(SessionEndPayload(
            sessionSyncID: snapshot?.sessionSyncID ?? UUID(), endTime: endTime
        ))
    }

    func apply(_ event: SessionSyncEvent) {
        switch event {
        case .sessionStarted(let payload):
            snapshot = LiveSessionSnapshot(
                sessionSyncID: payload.sessionSyncID, startTime: payload.startTime,
                gymName: payload.gymName, climbType: payload.climbType, problems: []
            )
        case .attemptLogged(let payload):
            countAttempt(payload)
        case .sessionEnded(let payload):
            guard payload.sessionSyncID == snapshot?.sessionSyncID else { return }
            snapshot = nil
        case .sessionSnapshot(let payload):
            guard snapshot == nil else { return }
            snapshot = payload.liveSession
        case .workoutRecorded, .liveSessionRequest, .phoneCatalog:
            // Not part of live session state.
            return
        }
        persist()
    }

    private func countAttempt(_ payload: AttemptLogPayload) {
        guard var current = snapshot, payload.sessionSyncID == current.sessionSyncID else {
            return
        }
        var problems = current.problems
        let index = problems.firstIndex { $0.colorGrade == payload.colorGrade }
            ?? appendProblem(payload, to: &problems)
        problems[index] = incremented(problems[index], by: payload.result)
        current = LiveSessionSnapshot(
            sessionSyncID: current.sessionSyncID, startTime: current.startTime,
            gymName: current.gymName, climbType: current.climbType, problems: problems
        )
        snapshot = current
    }

    private func appendProblem(
        _ payload: AttemptLogPayload, to problems: inout [ProblemCountsSnapshot]
    ) -> Int {
        problems.append(ProblemCountsSnapshot(
            problemSyncID: payload.problemSyncID, colorGrade: payload.colorGrade,
            flashCount: 0, sendCount: 0, fallCount: 0
        ))
        return problems.count - 1
    }

    private func incremented(
        _ counts: ProblemCountsSnapshot, by result: AttemptResult
    ) -> ProblemCountsSnapshot {
        ProblemCountsSnapshot(
            problemSyncID: counts.problemSyncID,
            colorGrade: counts.colorGrade,
            flashCount: counts.flashCount + (result == .flash ? 1 : 0),
            sendCount: counts.sendCount + (result == .send ? 1 : 0),
            fallCount: counts.fallCount + (result == .fall ? 1 : 0)
        )
    }

    /// One problem per grade, reusing the existing id so repeat logs merge on the phone.
    private func problemSyncID(for grade: ColorGrade) -> UUID {
        snapshot?.problems.first { $0.colorGrade == grade }?.problemSyncID ?? UUID()
    }

    private func persist() {
        guard let snapshot else {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func storedSnapshot(at fileURL: URL) -> LiveSessionSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(LiveSessionSnapshot.self, from: data)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run the global iOS test command. Expected: PASS.

Then the watch build command. Expected: build succeeds.

- [ ] **Step 5: Commit**

```bash
git add Shared/Sync/WatchLiveSession.swift BoulderTrackerTests/WatchLiveSessionTests.swift
git commit -m "feat: add persistent watch live session state"
```

---

### Task 10: Live workout session on the watch

**Files:**
- Create: `BoulderTrackerWatch/LiveWorkoutSession.swift`
- Create: `BoulderTrackerWatch/WorkoutMetrics.swift`

**Interfaces:**
- Consumes: nothing from earlier tasks except `WorkoutSummaryPayload`'s field shapes.
- Produces: `struct WorkoutMetrics`; `@MainActor @Observable final class LiveWorkoutSession` with `currentHeartRate: Double?`, `metrics: WorkoutMetrics?`, `func requestAuthorization() async throws`, `func begin(at:) async throws`, `func end(at:) async throws`. Task 11 drives it and reads `metrics` after `end`.

No unit tests: `HKLiveWorkoutBuilder` cannot be exercised off-device. Verified by hand in Task 11.

- [ ] **Step 1: Write the metrics type**

Create `BoulderTrackerWatch/WorkoutMetrics.swift`:

```swift
import Foundation

struct WorkoutMetrics: Sendable, Equatable {
    let workoutID: UUID
    let avgHeartRate: Double?
    let maxHeartRate: Double?
    let activeCalories: Double?
}
```

- [ ] **Step 2: Write the live workout session**

Create `BoulderTrackerWatch/LiveWorkoutSession.swift`:

```swift
import Foundation
import HealthKit
import Observation

enum LiveWorkoutFailure: Error {
    case healthDataUnavailable
    case builderMissing
    case workoutMissing
}

/// Runs the real `HKWorkoutSession` on the watch, which is what earns live heart
/// rate, calories, and activity-ring credit. `end(at:)` populates `metrics`.
@MainActor
@Observable
final class LiveWorkoutSession: NSObject {
    private(set) var currentHeartRate: Double?
    private(set) var metrics: WorkoutMetrics?

    @ObservationIgnored private let store = HKHealthStore()
    @ObservationIgnored private var session: HKWorkoutSession?
    @ObservationIgnored private var builder: HKLiveWorkoutBuilder?

    private let heartRateType = HKQuantityType(.heartRate)
    private let activeEnergyType = HKQuantityType(.activeEnergyBurned)

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw LiveWorkoutFailure.healthDataUnavailable
        }
        try await store.requestAuthorization(
            toShare: [HKObjectType.workoutType(), activeEnergyType],
            read: [heartRateType, activeEnergyType]
        )
    }

    func begin(at startTime: Date) async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw LiveWorkoutFailure.healthDataUnavailable
        }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .climbing
        configuration.locationType = .indoor

        let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(
            healthStore: store, workoutConfiguration: configuration
        )
        builder.delegate = self

        self.session = session
        self.builder = builder

        session.startActivity(with: startTime)
        try await builder.beginCollection(at: startTime)
    }

    func end(at endTime: Date) async throws {
        guard let session, let builder else { throw LiveWorkoutFailure.builderMissing }
        session.end()
        try await builder.endCollection(at: endTime)
        let summary = statisticsSummary(from: builder)
        guard let workout = try await builder.finishWorkout() else {
            throw LiveWorkoutFailure.workoutMissing
        }
        metrics = WorkoutMetrics(
            workoutID: workout.uuid,
            avgHeartRate: summary.average,
            maxHeartRate: summary.maximum,
            activeCalories: summary.calories
        )
        self.session = nil
        self.builder = nil
    }

    private func statisticsSummary(
        from builder: HKLiveWorkoutBuilder
    ) -> (average: Double?, maximum: Double?, calories: Double?) {
        let beatsPerMinute = HKUnit.count().unitDivided(by: .minute())
        let heartRate = builder.statistics(for: heartRateType)
        let energy = builder.statistics(for: activeEnergyType)
        return (
            heartRate?.averageQuantity()?.doubleValue(for: beatsPerMinute),
            heartRate?.maximumQuantity()?.doubleValue(for: beatsPerMinute),
            energy?.sumQuantity()?.doubleValue(for: .kilocalorie())
        )
    }

    fileprivate func refreshHeartRate(from builder: HKLiveWorkoutBuilder) {
        let beatsPerMinute = HKUnit.count().unitDivided(by: .minute())
        currentHeartRate = builder.statistics(for: heartRateType)?
            .mostRecentQuantity()?.doubleValue(for: beatsPerMinute)
    }
}

extension LiveWorkoutSession: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        guard collectedTypes.contains(HKQuantityType(.heartRate)) else { return }
        Task { @MainActor in self.refreshHeartRate(from: workoutBuilder) }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}

extension LiveWorkoutSession: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState, date: Date
    ) {}

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession, didFailWithError error: Error
    ) {}
}
```

`statisticsSummary` must be read **before** `finishWorkout()` — the builder's statistics are unavailable afterwards. Do not reorder those two lines.

- [ ] **Step 3: Build for the watch**

Run the watch build command. Expected: build succeeds.

- [ ] **Step 4: Run the iOS suite**

Run the global iOS test command. Expected: PASS — nothing in the iOS target changed.

- [ ] **Step 5: Commit**

```bash
git add BoulderTrackerWatch
git commit -m "feat: run a live HealthKit climbing workout on the watch"
```

---

### Task 11: Watch UI and sync wiring

**Files:**
- Create: `BoulderTrackerWatch/WatchSyncCoordinator.swift`
- Create: `BoulderTrackerWatch/WatchRootView.swift`
- Create: `BoulderTrackerWatch/WatchStartView.swift`
- Create: `BoulderTrackerWatch/WatchLiveView.swift`
- Create: `BoulderTrackerWatch/WatchLogSheet.swift`
- Create: `BoulderTrackerWatch/WatchSummaryView.swift`
- Modify: `BoulderTrackerWatch/BoulderTrackerWatchApp.swift`

**Interfaces:**
- Consumes: Tasks 2, 5, 6, 9, 10.
- Produces: the running watch app. Nothing later depends on it.

- [ ] **Step 1: Write the watch coordinator**

Create `BoulderTrackerWatch/WatchSyncCoordinator.swift`:

```swift
import Foundation
import Observation

/// Owns the watch side: link, outbox, live session state, and the workout. UI calls
/// the four intent methods; everything else is event plumbing.
@MainActor
@Observable
final class WatchSyncCoordinator {
    let liveSession: WatchLiveSession
    let workout = LiveWorkoutSession()

    private(set) var gyms: [GymSnapshot] = []
    private(set) var lastMetrics: WorkoutMetrics?
    private(set) var finishedDuration: TimeInterval?

    @ObservationIgnored private let link = WatchConnectivityLink()
    @ObservationIgnored private let outbox: SessionSyncOutbox
    @ObservationIgnored private var healthKitSyncEnabled = true

    init() {
        liveSession = WatchLiveSession(fileURL: Self.liveSessionFileURL())
        outbox = SessionSyncOutbox(
            queue: .inApplicationSupport(named: "watch-sync-queue.json"), link: link
        )
    }

    func start() {
        link.onReceive = { [weak self] envelope in self?.route(envelope) }
        link.activate()
        outbox.resendPending()
        if liveSession.snapshot == nil {
            outbox.send(.liveSessionRequest)
        }
    }

    func beginSession(gymName: String?, climbType: ClimbType) {
        let event = liveSession.startEvent(
            gymName: gymName, climbType: climbType, startTime: .now
        )
        liveSession.apply(event)
        outbox.send(event)
        startWorkout()
    }

    func log(grade: ColorGrade, result: AttemptResult) {
        let event = liveSession.attemptEvent(grade: grade, result: result, loggedAt: .now)
        liveSession.apply(event)
        outbox.send(event)
    }

    func finishSession() {
        guard let snapshot = liveSession.snapshot else { return }
        let endTime = Date.now
        finishedDuration = endTime.timeIntervalSince(snapshot.startTime)
        let event = liveSession.endEvent(endTime: endTime)
        liveSession.apply(event)
        outbox.send(event)
        finishWorkout(sessionSyncID: snapshot.sessionSyncID, endTime: endTime)
    }

    func dismissSummary() {
        finishedDuration = nil
        lastMetrics = nil
    }

    private func route(_ envelope: SyncEnvelope) {
        if case .phoneCatalog(let payload) = envelope.event {
            gyms = payload.gyms
            healthKitSyncEnabled = payload.healthKitSyncEnabled
            return
        }
        liveSession.apply(envelope.event)
    }

    private func startWorkout() {
        guard healthKitSyncEnabled else { return }
        Task {
            do {
                try await workout.requestAuthorization()
                try await workout.begin(at: .now)
            } catch {
                // Logging continues without heart rate; the session itself is unaffected.
                healthKitSyncEnabled = false
            }
        }
    }

    private func finishWorkout(sessionSyncID: UUID, endTime: Date) {
        guard healthKitSyncEnabled else { return }
        Task {
            do {
                try await workout.end(at: endTime)
            } catch {
                return
            }
            guard let metrics = workout.metrics else { return }
            lastMetrics = metrics
            outbox.send(.workoutRecorded(WorkoutSummaryPayload(
                sessionSyncID: sessionSyncID,
                workoutID: metrics.workoutID,
                avgHeartRate: metrics.avgHeartRate,
                maxHeartRate: metrics.maxHeartRate,
                activeCalories: metrics.activeCalories
            )))
        }
    }

    private static func liveSessionFileURL() -> URL {
        let directory = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0]
        try? FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true
        )
        return directory.appendingPathComponent("watch-live-session.json")
    }
}
```

- [ ] **Step 2: Write the start screen**

Create `BoulderTrackerWatch/WatchStartView.swift`:

```swift
import SwiftUI

struct WatchStartView: View {
    let gyms: [GymSnapshot]
    let onStart: (String?, ClimbType) -> Void

    @State private var climbType: ClimbType = .bouldering

    var body: some View {
        List {
            Section("Type") {
                Picker("Type", selection: $climbType) {
                    ForEach(ClimbType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.navigationLink)
            }
            Section("Gym") {
                ForEach(gyms, id: \.name) { gym in
                    Button(gym.name) { onStart(gym.name, climbType) }
                }
                Button("No gym") { onStart(nil, climbType) }
            }
        }
        .navigationTitle("Start")
    }
}
```

- [ ] **Step 3: Write the log sheet**

Create `BoulderTrackerWatch/WatchLogSheet.swift`:

```swift
import SwiftUI

struct WatchLogSheet: View {
    let onLog: (ColorGrade, AttemptResult) -> Void

    @State private var grade: ColorGrade?

    var body: some View {
        if let grade {
            resultList(for: grade)
        } else {
            gradeList
        }
    }

    private var gradeList: some View {
        List(ColorGrade.displayOrder) { option in
            Button {
                grade = option
            } label: {
                Text(option.displayName)
            }
        }
        .navigationTitle("Grade")
    }

    private func resultList(for grade: ColorGrade) -> some View {
        List(AttemptResult.allCases) { result in
            Button(result.displayName) { onLog(grade, result) }
        }
        .navigationTitle(grade.displayName)
    }
}
```

- [ ] **Step 4: Write the live screen**

Create `BoulderTrackerWatch/WatchLiveView.swift`:

```swift
import SwiftUI

struct WatchLiveView: View {
    let snapshot: LiveSessionSnapshot
    let tally: [(grade: ColorGrade, count: Int)]
    let heartRate: Double?
    let onLog: (ColorGrade, AttemptResult) -> Void
    let onEnd: () -> Void

    @State private var isLogging = false
    @State private var isConfirmingEnd = false

    var body: some View {
        List {
            Section {
                elapsedText
                heartRateText
            }
            if !tally.isEmpty {
                Section("Logged") {
                    ForEach(tally, id: \.grade) { entry in
                        HStack {
                            Text(entry.grade.displayName)
                            Spacer()
                            Text("\(entry.count)").monospacedDigit()
                        }
                    }
                }
            }
            Section {
                Button("Log") { isLogging = true }
                Button("End", role: .destructive) { isConfirmingEnd = true }
            }
        }
        .navigationTitle(snapshot.gymName ?? "Session")
        .sheet(isPresented: $isLogging) {
            NavigationStack {
                WatchLogSheet { grade, result in
                    onLog(grade, result)
                    isLogging = false
                }
            }
        }
        .confirmationDialog("End session?", isPresented: $isConfirmingEnd) {
            Button("End", role: .destructive, action: onEnd)
        }
    }

    private var elapsedText: some View {
        TimelineView(.periodic(from: snapshot.startTime, by: 1)) { context in
            Text(elapsedLabel(at: context.date))
                .font(.system(size: 30, weight: .bold))
                .monospacedDigit()
        }
    }

    @ViewBuilder private var heartRateText: some View {
        if let heartRate {
            Label("\(Int(heartRate.rounded())) BPM", systemImage: "heart.fill")
                .foregroundStyle(.red)
        }
    }

    private func elapsedLabel(at now: Date) -> String {
        let elapsed = Int(max(0, now.timeIntervalSince(snapshot.startTime)))
        let hours = elapsed / 3600
        let minutes = (elapsed % 3600) / 60
        let seconds = elapsed % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
```

`SessionDurationFormat` lives in the iOS target and is not shared, so this view formats its own label.

- [ ] **Step 5: Write the summary screen**

Create `BoulderTrackerWatch/WatchSummaryView.swift`:

```swift
import SwiftUI

struct WatchSummaryView: View {
    let duration: TimeInterval
    let metrics: WorkoutMetrics?
    let onDone: () -> Void

    var body: some View {
        List {
            LabeledContent("Duration", value: durationLabel)
            if let avgHeartRate = metrics?.avgHeartRate {
                LabeledContent("Avg BPM", value: "\(Int(avgHeartRate.rounded()))")
            }
            if let calories = metrics?.activeCalories {
                LabeledContent("Calories", value: "\(Int(calories.rounded()))")
            }
            Button("Done", action: onDone)
        }
        .navigationTitle("Done")
    }

    private var durationLabel: String {
        let minutes = Int(duration) / 60
        return "\(minutes) min"
    }
}
```

- [ ] **Step 6: Write the root view and app entry**

Create `BoulderTrackerWatch/WatchRootView.swift`:

```swift
import SwiftUI

struct WatchRootView: View {
    @State private var coordinator = WatchSyncCoordinator()

    var body: some View {
        NavigationStack {
            content
        }
        .task { coordinator.start() }
    }

    @ViewBuilder private var content: some View {
        if let duration = coordinator.finishedDuration {
            WatchSummaryView(duration: duration, metrics: coordinator.lastMetrics) {
                coordinator.dismissSummary()
            }
        } else if let snapshot = coordinator.liveSession.snapshot {
            WatchLiveView(
                snapshot: snapshot,
                tally: coordinator.liveSession.tally,
                heartRate: coordinator.workout.currentHeartRate,
                onLog: { grade, result in coordinator.log(grade: grade, result: result) },
                onEnd: { coordinator.finishSession() }
            )
        } else {
            WatchStartView(gyms: coordinator.gyms) { gymName, climbType in
                coordinator.beginSession(gymName: gymName, climbType: climbType)
            }
        }
    }
}
```

Replace the body of `BoulderTrackerWatch/BoulderTrackerWatchApp.swift`:

```swift
import SwiftUI

@main
struct BoulderTrackerWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchRootView()
        }
    }
}
```

- [ ] **Step 7: Build and run the full suite**

Run the watch build command. Expected: build succeeds.
Run the global iOS test command. Expected: PASS.

- [ ] **Step 8: Verify by hand on a paired simulator**

This is the only check that covers WatchConnectivity and HealthKit, neither of which unit tests can reach.

```bash
xcrun simctl list devices available | grep -i watch
```

Boot the paired iPhone and Watch simulators, run both schemes, and confirm:

1. Start a session on the watch → it appears in the iPhone Home tab as a live session.
2. Log a red Send on the watch → the phone's grade tally shows Red 1.
3. Log a blue Flash on the phone → the watch tally shows Blue 1.
4. End on the watch → the phone shows the session summary with a duration.
5. Kill the watch app mid-session and relaunch → the live session and its tally are still there.

Heart rate is unavailable in the simulator; verify it on a real watch if one is paired.

- [ ] **Step 9: Commit**

```bash
git add BoulderTrackerWatch
git commit -m "feat: add watch logging UI wired to sync and the live workout"
```

---

## Deviations from the spec

Both were found while writing the code and are deliberate:

1. **`.problemCreated` removed.** `.attemptLogged` carries `colorGrade`, so a receiver creates the problem on first log. This drops an event case and removes the ordering hazard where a log could arrive before the problem it targets. The orphan buffer still handles a log arriving before its *session*.
2. **`syncID` is `UUID?`, not `UUID`.** A non-optional property with a default would give every row migrated from the pre-sync schema the same UUID, breaking lookup-by-syncID. Optional means those rows stay unmatched, which is correct — they were never synced.
