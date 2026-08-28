# Boulder Tracker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Personal iOS bouldering tracker — session logging (live + retro), per-problem attempts with photos, calendar, stats, manual roadmap, achievements, HealthKit workout writes.

**Architecture:** SwiftUI + SwiftData, local storage only, iOS 26 Liquid Glass. Views are dumb; all logic lives in pure, testable units (`StatsAggregator`, `AchievementEngine`, `PhotoStore`) plus a protocol-wrapped `HealthKitWriter`. One type per file, feature folders.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, Swift Charts, HealthKit, Swift Testing (`import Testing`), XcodeGen for project generation. Zero third-party runtime dependencies.

**Spec:** `docs/superpowers/specs/2026-08-28-boulder-tracker-design.md`

## Global Constraints

- iOS deployment target: **26.0**, iPhone only.
- No third-party runtime packages. XcodeGen is a dev tool only.
- Grade system fixed to Klättervigören Jönköping: green (4–5b / V0–V1), blue (5b–6a / V1–V3), red (6a–6c / V3–V5), black (6c–7a / V5–V7), white (7b–7c / V8–V10), yellow (8a+ / V11+).
- One type per file; files ≤300 LOC; functions ≤30 LOC; no `TODO` markers; no domain string literals in control flow (use the enums); no swallowed exceptions.
- Models and Services must not import SwiftUI. Display-only extensions live outside `Models/`.
- Tests use Swift Testing (`@Test`, `#expect`), never XCTest.
- Test command (all tasks): `xcodebuild test -project BoulderTracker.xcodeproj -scheme BoulderTracker -destination "platform=iOS Simulator,name=iPhone 17 Pro" -quiet`. If that simulator name is absent, first run `xcrun simctl list devices available` and substitute the newest available iPhone for every test/build command in this plan.
- Commit messages: plain conventional style (`feat:`, `test:`, `chore:`), **no Co-Authored-By lines**.
- HealthKit writes are best-effort — they must never block or fail a local session save.

---

### Task 1: Project scaffold

**Files:**
- Create: `.gitignore`
- Create: `project.yml`
- Create: `BoulderTracker/App/BoulderTrackerApp.swift`
- Create: `BoulderTracker/App/RootTabView.swift`
- Create: `BoulderTracker/Info.plist` (via project.yml properties)
- Create: `BoulderTrackerTests/SmokeTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: buildable app + test target. `RootTabView` with five placeholder tabs that later tasks replace one by one. Enum `AppTab` naming the tabs.

- [ ] **Step 1: Init git repo**

```bash
cd /Users/liammelkersson/dev/boulder-tracker && git init
```

- [ ] **Step 2: Write .gitignore**

```gitignore
.DS_Store
xcuserdata/
*.xcodeproj/project.xcworkspace/xcuserdata/
build/
DerivedData/
```

- [ ] **Step 3: Check XcodeGen available**

Run: `which xcodegen || brew install xcodegen`

If brew install fails (sandbox/network), STOP and ask the user to install XcodeGen, per global sandbox rules.

- [ ] **Step 4: Write project.yml**

```yaml
name: BoulderTracker
options:
  bundleIdPrefix: com.liammelkersson
  deploymentTarget:
    iOS: "26.0"
targets:
  BoulderTracker:
    type: application
    platform: iOS
    sources: [BoulderTracker]
    settings:
      base:
        SWIFT_VERSION: "6.0"
        TARGETED_DEVICE_FAMILY: "1"
        GENERATE_INFOPLIST_FILE: true
        INFOPLIST_KEY_NSCameraUsageDescription: "Photograph boulder problems you log."
        INFOPLIST_KEY_NSPhotoLibraryAddUsageDescription: "Save route photos you take."
        INFOPLIST_KEY_NSHealthUpdateUsageDescription: "Save climbing sessions as workouts in Apple Health."
        INFOPLIST_KEY_NSHealthShareUsageDescription: "Not used for reading; required by HealthKit entitlement."
        CODE_SIGN_ENTITLEMENTS: BoulderTracker/BoulderTracker.entitlements
  BoulderTrackerTests:
    type: bundle.unit-test
    platform: iOS
    sources: [BoulderTrackerTests]
    dependencies:
      - target: BoulderTracker
schemes:
  BoulderTracker:
    build:
      targets:
        BoulderTracker: all
    test:
      targets: [BoulderTrackerTests]
```

- [ ] **Step 5: Write entitlements file** `BoulderTracker/BoulderTracker.entitlements`

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

- [ ] **Step 6: Write app entry** `BoulderTracker/App/BoulderTrackerApp.swift`

```swift
import SwiftUI
import SwiftData

@main
struct BoulderTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(for: [
            Session.self, ProblemAttempt.self, Gym.self, Partner.self,
            RoadmapProgress.self, Achievement.self,
        ])
    }
}
```

Note: this references model types from Task 3. Until Task 3 lands, use an empty
`WindowGroup { RootTabView() }` with no `.modelContainer` — add the container line in Task 3.

- [ ] **Step 7: Write RootTabView** `BoulderTracker/App/RootTabView.swift`

```swift
import SwiftUI

enum AppTab: Hashable {
    case home, calendar, stats, roadmap, profile
}

struct RootTabView: View {
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "figure.climbing", value: .home) {
                Text("Home")
            }
            Tab("Calendar", systemImage: "calendar", value: .calendar) {
                Text("Calendar")
            }
            Tab("Stats", systemImage: "chart.bar.xaxis", value: .stats) {
                Text("Stats")
            }
            Tab("Roadmap", systemImage: "map", value: .roadmap) {
                Text("Roadmap")
            }
            Tab("Profile", systemImage: "person.crop.circle", value: .profile) {
                Text("Profile")
            }
        }
    }
}
```

- [ ] **Step 8: Write smoke test** `BoulderTrackerTests/SmokeTests.swift`

```swift
import Testing
@testable import BoulderTracker

struct SmokeTests {
    @Test func appTabHasFiveCases() {
        let tabs: [AppTab] = [.home, .calendar, .stats, .roadmap, .profile]
        #expect(tabs.count == 5)
    }
}
```

- [ ] **Step 9: Generate project and run tests**

```bash
xcodegen generate
xcodebuild test -project BoulderTracker.xcodeproj -scheme BoulderTracker -destination "platform=iOS Simulator,name=iPhone 17 Pro" -quiet
```

Expected: build succeeds, 1 test passes.

- [ ] **Step 10: Commit**

```bash
git add -A && git commit -m "chore: scaffold BoulderTracker Xcode project with XcodeGen"
```

---

### Task 2: Grade, style, and result enums

**Files:**
- Create: `BoulderTracker/Models/ColorGrade.swift`
- Create: `BoulderTracker/Models/RouteStyle.swift`
- Create: `BoulderTracker/Models/AttemptResult.swift`
- Create: `BoulderTracker/App/ColorGradeDisplay.swift` (SwiftUI color lives outside Models)
- Test: `BoulderTrackerTests/ColorGradeTests.swift`, `BoulderTrackerTests/AttemptResultTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum ColorGrade: Int, Codable, CaseIterable, Comparable, Identifiable` — cases `green, blue, red, black, white, yellow`; `var displayName: String`, `var frenchRange: String`, `var vGradeRange: String`.
  - `enum RouteStyle: String, Codable, CaseIterable, Identifiable` — cases `dyno, sloper, crimp, jug, pinch, pocket, overhang, slab, vertical, roof, compression, coordination, mantle, arete, traverse`; `var displayName: String`.
  - `enum AttemptResult: String, Codable, CaseIterable, Identifiable` — cases `flash, send, project`; `var countsAsSend: Bool`, `var displayName: String`.
  - `extension ColorGrade { var displayColor: Color }` (in App/).

- [ ] **Step 1: Write failing tests** `BoulderTrackerTests/ColorGradeTests.swift`

```swift
import Testing
@testable import BoulderTracker

struct ColorGradeTests {
    @Test func gradesOrderEasiestToHardest() {
        #expect(ColorGrade.green < ColorGrade.blue)
        #expect(ColorGrade.blue < ColorGrade.red)
        #expect(ColorGrade.red < ColorGrade.black)
        #expect(ColorGrade.black < ColorGrade.white)
        #expect(ColorGrade.white < ColorGrade.yellow)
    }

    @Test func gradeRangesMatchGymScale() {
        #expect(ColorGrade.green.frenchRange == "4–5b")
        #expect(ColorGrade.green.vGradeRange == "V0–V1")
        #expect(ColorGrade.yellow.frenchRange == "8a+")
        #expect(ColorGrade.yellow.vGradeRange == "V11+")
    }

    @Test func allSixGradesExist() {
        #expect(ColorGrade.allCases.count == 6)
    }
}
```

`BoulderTrackerTests/AttemptResultTests.swift`:

```swift
import Testing
@testable import BoulderTracker

struct AttemptResultTests {
    @Test func flashAndSendCountAsSends() {
        #expect(AttemptResult.flash.countsAsSend)
        #expect(AttemptResult.send.countsAsSend)
        #expect(!AttemptResult.project.countsAsSend)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run the global test command. Expected: FAIL — `ColorGrade` not found.

- [ ] **Step 3: Implement enums**

`BoulderTracker/Models/ColorGrade.swift`:

```swift
import Foundation

enum ColorGrade: Int, Codable, CaseIterable, Comparable, Identifiable {
    case green, blue, red, black, white, yellow

    var id: Int { rawValue }

    static func < (lhs: ColorGrade, rhs: ColorGrade) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .green: "Green"
        case .blue: "Blue"
        case .red: "Red"
        case .black: "Black"
        case .white: "White"
        case .yellow: "Yellow"
        }
    }

    var frenchRange: String {
        switch self {
        case .green: "4–5b"
        case .blue: "5b–6a"
        case .red: "6a–6c"
        case .black: "6c–7a"
        case .white: "7b–7c"
        case .yellow: "8a+"
        }
    }

    var vGradeRange: String {
        switch self {
        case .green: "V0–V1"
        case .blue: "V1–V3"
        case .red: "V3–V5"
        case .black: "V5–V7"
        case .white: "V8–V10"
        case .yellow: "V11+"
        }
    }
}
```

`BoulderTracker/Models/RouteStyle.swift`:

```swift
import Foundation

enum RouteStyle: String, Codable, CaseIterable, Identifiable {
    case dyno, sloper, crimp, jug, pinch, pocket, overhang, slab
    case vertical, roof, compression, coordination, mantle, arete, traverse

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .arete: "Arête"
        default: rawValue.capitalized
        }
    }
}
```

`BoulderTracker/Models/AttemptResult.swift`:

```swift
import Foundation

enum AttemptResult: String, Codable, CaseIterable, Identifiable {
    case flash, send, project

    var id: String { rawValue }

    var countsAsSend: Bool { self != .project }

    var displayName: String { rawValue.capitalized }
}
```

`BoulderTracker/App/ColorGradeDisplay.swift`:

```swift
import SwiftUI

extension ColorGrade {
    var displayColor: Color {
        switch self {
        case .green: .green
        case .blue: .blue
        case .red: .red
        case .black: .primary
        case .white: .gray
        case .yellow: .yellow
        }
    }
}
```

- [ ] **Step 4: Regenerate project, run tests, verify pass**

```bash
xcodegen generate
```

Then the global test command. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add grade, style, and result enums with gym scale metadata"
```

---

### Task 3: SwiftData models + gym seeding

**Files:**
- Create: `BoulderTracker/Models/Session.swift`
- Create: `BoulderTracker/Models/ProblemAttempt.swift`
- Create: `BoulderTracker/Models/Gym.swift`
- Create: `BoulderTracker/Models/Partner.swift`
- Create: `BoulderTracker/Models/RoadmapProgress.swift`
- Create: `BoulderTracker/Models/Achievement.swift`
- Create: `BoulderTracker/Services/DefaultGymSeeder.swift`
- Modify: `BoulderTracker/App/BoulderTrackerApp.swift` (add modelContainer + seeding)
- Test: `BoulderTrackerTests/ModelRoundTripTests.swift`

**Interfaces:**
- Consumes: Task 2 enums.
- Produces:
  - `@Model final class Session` — `date: Date`, `startTime: Date`, `endTime: Date?`, `notes: String?`, `healthKitWorkoutID: UUID?`, `gym: Gym?`, `partners: [Partner]`, `attempts: [ProblemAttempt]` (cascade), `var duration: TimeInterval`, `var isLive: Bool`. Init: `init(startTime: Date, gym: Gym?, partners: [Partner])`.
  - `@Model final class ProblemAttempt` — `colorGrade: ColorGrade`, `styles: [RouteStyle]`, `attemptCount: Int`, `result: AttemptResult`, `photoFilename: String?`, `notes: String?`, `session: Session?`. Init: `init(colorGrade: ColorGrade, styles: [RouteStyle], attemptCount: Int, result: AttemptResult)`.
  - `@Model final class Gym` — `name: String`, `isDefault: Bool`.
  - `@Model final class Partner` — `name: String`.
  - `@Model final class RoadmapProgress` — `itemID: String`, `checkedAt: Date`.
  - `@Model final class Achievement` — `id: String` (stored as `achievementID: String` since `id` collides), `unlockedAt: Date`.
  - `enum DefaultGymSeeder { static func seedIfNeeded(context: ModelContext) throws }` — inserts Gym "Klättervigören Jönköping" with `isDefault: true` when no gyms exist.
  - Test helper `func makeInMemoryContainer() throws -> ModelContainer` in the test target.

- [ ] **Step 1: Write failing tests** `BoulderTrackerTests/ModelRoundTripTests.swift`

```swift
import Testing
import SwiftData
@testable import BoulderTracker

@MainActor
func makeInMemoryContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: Session.self, ProblemAttempt.self, Gym.self, Partner.self,
        RoadmapProgress.self, Achievement.self,
        configurations: config
    )
}

@MainActor
struct ModelRoundTripTests {
    @Test func sessionRoundTripsWithAttempts() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let gym = Gym(name: "Klättervigören Jönköping", isDefault: true)
        let session = Session(startTime: .now, gym: gym, partners: [])
        let attempt = ProblemAttempt(
            colorGrade: .red, styles: [.overhang, .sloper],
            attemptCount: 3, result: .send
        )
        session.attempts.append(attempt)
        context.insert(session)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Session>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.attempts.count == 1)
        #expect(fetched.first?.attempts.first?.styles == [.overhang, .sloper])
        #expect(fetched.first?.gym?.name == "Klättervigören Jönköping")
    }

    @Test func deletingSessionCascadesToAttempts() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let session = Session(startTime: .now, gym: nil, partners: [])
        session.attempts.append(ProblemAttempt(
            colorGrade: .green, styles: [], attemptCount: 1, result: .flash
        ))
        context.insert(session)
        try context.save()

        context.delete(session)
        try context.save()

        let attempts = try context.fetch(FetchDescriptor<ProblemAttempt>())
        #expect(attempts.isEmpty)
    }

    @Test func seederInsertsDefaultGymOnce() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        try DefaultGymSeeder.seedIfNeeded(context: context)
        try DefaultGymSeeder.seedIfNeeded(context: context)

        let gyms = try context.fetch(FetchDescriptor<Gym>())
        #expect(gyms.count == 1)
        #expect(gyms.first?.isDefault == true)
    }

    @Test func liveSessionHasNilEndTime() throws {
        let session = Session(startTime: .now, gym: nil, partners: [])
        #expect(session.isLive)
        session.endTime = .now
        #expect(!session.isLive)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL — `Session` not found.

- [ ] **Step 3: Implement models**

`BoulderTracker/Models/Session.swift`:

```swift
import Foundation
import SwiftData

@Model
final class Session {
    var date: Date
    var startTime: Date
    var endTime: Date?
    var notes: String?
    var healthKitWorkoutID: UUID?
    var gym: Gym?
    var partners: [Partner]
    @Relationship(deleteRule: .cascade, inverse: \ProblemAttempt.session)
    var attempts: [ProblemAttempt]

    init(startTime: Date, gym: Gym?, partners: [Partner]) {
        self.date = startTime
        self.startTime = startTime
        self.endTime = nil
        self.gym = gym
        self.partners = partners
        self.attempts = []
    }

    var isLive: Bool { endTime == nil }

    var duration: TimeInterval {
        (endTime ?? startTime).timeIntervalSince(startTime)
    }
}
```

`BoulderTracker/Models/ProblemAttempt.swift`:

```swift
import Foundation
import SwiftData

@Model
final class ProblemAttempt {
    var colorGrade: ColorGrade
    var styles: [RouteStyle]
    var attemptCount: Int
    var result: AttemptResult
    var photoFilename: String?
    var notes: String?
    var session: Session?

    init(colorGrade: ColorGrade, styles: [RouteStyle], attemptCount: Int, result: AttemptResult) {
        self.colorGrade = colorGrade
        self.styles = styles
        self.attemptCount = attemptCount
        self.result = result
    }
}
```

`BoulderTracker/Models/Gym.swift`:

```swift
import Foundation
import SwiftData

@Model
final class Gym {
    var name: String
    var isDefault: Bool

    init(name: String, isDefault: Bool = false) {
        self.name = name
        self.isDefault = isDefault
    }
}
```

`BoulderTracker/Models/Partner.swift`:

```swift
import Foundation
import SwiftData

@Model
final class Partner {
    var name: String

    init(name: String) {
        self.name = name
    }
}
```

`BoulderTracker/Models/RoadmapProgress.swift`:

```swift
import Foundation
import SwiftData

@Model
final class RoadmapProgress {
    @Attribute(.unique) var itemID: String
    var checkedAt: Date

    init(itemID: String, checkedAt: Date = .now) {
        self.itemID = itemID
        self.checkedAt = checkedAt
    }
}
```

`BoulderTracker/Models/Achievement.swift`:

```swift
import Foundation
import SwiftData

@Model
final class Achievement {
    @Attribute(.unique) var achievementID: String
    var unlockedAt: Date

    init(achievementID: String, unlockedAt: Date = .now) {
        self.achievementID = achievementID
        self.unlockedAt = unlockedAt
    }
}
```

`BoulderTracker/Services/DefaultGymSeeder.swift`:

```swift
import Foundation
import SwiftData

enum DefaultGymSeeder {
    static let defaultGymName = "Klättervigören Jönköping"

    static func seedIfNeeded(context: ModelContext) throws {
        let existing = try context.fetchCount(FetchDescriptor<Gym>())
        guard existing == 0 else { return }
        context.insert(Gym(name: defaultGymName, isDefault: true))
        try context.save()
    }
}
```

- [ ] **Step 4: Wire container + seeding in app entry**

Update `BoulderTrackerApp.swift` to the Task 1 Step 6 form (with `.modelContainer`), and run the seeder on appear:

```swift
import SwiftUI
import SwiftData

@main
struct BoulderTrackerApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: Session.self, ProblemAttempt.self, Gym.self, Partner.self,
                RoadmapProgress.self, Achievement.self
            )
            try DefaultGymSeeder.seedIfNeeded(context: container.mainContext)
        } catch {
            fatalError("Failed to initialize model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(container)
    }
}
```

- [ ] **Step 5: Regenerate, run tests, verify pass**

Expected: all tests PASS.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: add SwiftData models and default gym seeding"
```

---

### Task 4: PhotoStore

**Files:**
- Create: `BoulderTracker/Services/PhotoStore.swift`
- Test: `BoulderTrackerTests/PhotoStoreTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `struct PhotoStore` — `init(directory: URL)`, `static func makeDefault() -> PhotoStore` (Documents/RoutePhotos), `func savePhoto(_ jpegData: Data) throws -> String` (returns generated filename), `func photoURL(for filename: String) -> URL`, `func loadPhoto(named filename: String) -> Data?`, `func deletePhoto(named filename: String) throws`.

- [ ] **Step 1: Write failing tests** `BoulderTrackerTests/PhotoStoreTests.swift`

```swift
import Testing
import Foundation
@testable import BoulderTracker

struct PhotoStoreTests {
    private func makeTemporaryStore() -> PhotoStore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return PhotoStore(directory: dir)
    }

    @Test func savedPhotoRoundTrips() throws {
        let store = makeTemporaryStore()
        let original = Data([0xFF, 0xD8, 0xFF, 0xE0])

        let filename = try store.savePhoto(original)
        let loaded = store.loadPhoto(named: filename)

        #expect(loaded == original)
    }

    @Test func deletedPhotoIsGone() throws {
        let store = makeTemporaryStore()
        let filename = try store.savePhoto(Data([0x01]))

        try store.deletePhoto(named: filename)

        #expect(store.loadPhoto(named: filename) == nil)
    }

    @Test func savedFilenamesAreUnique() throws {
        let store = makeTemporaryStore()
        let first = try store.savePhoto(Data([0x01]))
        let second = try store.savePhoto(Data([0x01]))
        #expect(first != second)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL — `PhotoStore` not found.

- [ ] **Step 3: Implement** `BoulderTracker/Services/PhotoStore.swift`

```swift
import Foundation

struct PhotoStore {
    private let directory: URL

    init(directory: URL) {
        self.directory = directory
    }

    static func makeDefault() -> PhotoStore {
        let documents = URL.documentsDirectory
        return PhotoStore(directory: documents.appendingPathComponent("RoutePhotos", isDirectory: true))
    }

    func savePhoto(_ jpegData: Data) throws -> String {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let filename = "\(UUID().uuidString).jpg"
        try jpegData.write(to: photoURL(for: filename), options: .atomic)
        return filename
    }

    func photoURL(for filename: String) -> URL {
        directory.appendingPathComponent(filename)
    }

    func loadPhoto(named filename: String) -> Data? {
        try? Data(contentsOf: photoURL(for: filename))
    }

    func deletePhoto(named filename: String) throws {
        try FileManager.default.removeItem(at: photoURL(for: filename))
    }
}
```

- [ ] **Step 4: Regenerate, run tests, verify pass**

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add PhotoStore for route photo persistence"
```

---

### Task 5: StatsAggregator

**Files:**
- Create: `BoulderTracker/Stats/StatsPeriod.swift`
- Create: `BoulderTracker/Stats/StatsSummary.swift`
- Create: `BoulderTracker/Stats/StatsAggregator.swift`
- Test: `BoulderTrackerTests/StatsAggregatorTests.swift`

**Interfaces:**
- Consumes: `Session`, `ProblemAttempt`, `ColorGrade`, `RouteStyle`, `AttemptResult` (Tasks 2–3).
- Produces:
  - `enum StatsPeriod: String, CaseIterable, Identifiable` — cases `month, threeMonths, year, all`; `var displayName: String`; `func interval(endingAt referenceDate: Date, calendar: Calendar) -> DateInterval?` (nil for `.all`).
  - `struct StatsSummary: Equatable` — `sessionCount: Int`, `totalDuration: TimeInterval`, `problemCount: Int`, `sendCount: Int`, `attemptCount: Int`, `flashCount: Int`; computed `completionRate: Double`, `flashRate: Double` (0 when no problems).
  - `enum StatsAggregator` with static pure functions:
    - `func sessions(_ sessions: [Session], in interval: DateInterval?) -> [Session]`
    - `func summary(of sessions: [Session]) -> StatsSummary`
    - `func climbingDayCount(of sessions: [Session], calendar: Calendar) -> Int`
    - `func sendCountPerGrade(of sessions: [Session]) -> [ColorGrade: Int]`
    - `func sendRatePerStyle(of sessions: [Session]) -> [RouteStyle: Double]`
    - `func hardestSend(of sessions: [Session]) -> ProblemAttempt?` (flash or send)
    - `func hardestFlash(of sessions: [Session]) -> ProblemAttempt?`
    - `func weeklyStreak(of sessions: [Session], calendar: Calendar, referenceDate: Date) -> Int` (consecutive weeks ending at referenceDate's week, each containing ≥1 session)
    - `func proudestSend(of sessions: [Session]) -> ProblemAttempt?` (hardest grade sent; ties broken by highest attemptCount, then latest session date)

- [ ] **Step 1: Write failing tests** `BoulderTrackerTests/StatsAggregatorTests.swift`

```swift
import Testing
import Foundation
@testable import BoulderTracker

@MainActor
struct StatsAggregatorTests {
    private let calendar = Calendar(identifier: .iso8601)

    private func makeSession(daysAgo: Int, durationMinutes: Int = 90,
                             referenceDate: Date = .now) -> Session {
        let start = calendar.date(byAdding: .day, value: -daysAgo, to: referenceDate)!
        let session = Session(startTime: start, gym: nil, partners: [])
        session.endTime = start.addingTimeInterval(TimeInterval(durationMinutes * 60))
        return session
    }

    private func addAttempt(_ session: Session, grade: ColorGrade,
                            styles: [RouteStyle] = [], attempts: Int = 1,
                            result: AttemptResult) {
        let attempt = ProblemAttempt(colorGrade: grade, styles: styles,
                                     attemptCount: attempts, result: result)
        session.attempts.append(attempt)
    }

    @Test func summaryCountsSendsFlashesAndRates() {
        let session = makeSession(daysAgo: 0)
        addAttempt(session, grade: .green, result: .flash)
        addAttempt(session, grade: .blue, attempts: 3, result: .send)
        addAttempt(session, grade: .red, attempts: 5, result: .project)

        let summary = StatsAggregator.summary(of: [session])

        #expect(summary.problemCount == 3)
        #expect(summary.sendCount == 2)
        #expect(summary.flashCount == 1)
        #expect(summary.attemptCount == 9)
        #expect(abs(summary.completionRate - 2.0 / 3.0) < 0.001)
        #expect(abs(summary.flashRate - 1.0 / 3.0) < 0.001)
    }

    @Test func emptySummaryHasZeroRates() {
        let summary = StatsAggregator.summary(of: [])
        #expect(summary.completionRate == 0)
        #expect(summary.flashRate == 0)
    }

    @Test func periodFilterExcludesOldSessions() {
        let recent = makeSession(daysAgo: 5)
        let old = makeSession(daysAgo: 400)
        let interval = StatsPeriod.threeMonths.interval(endingAt: .now, calendar: calendar)

        let filtered = StatsAggregator.sessions([recent, old], in: interval)

        #expect(filtered.count == 1)
    }

    @Test func allPeriodHasNilInterval() {
        #expect(StatsPeriod.all.interval(endingAt: .now, calendar: calendar) == nil)
    }

    @Test func climbingDaysCountsUniqueDays() {
        let morning = makeSession(daysAgo: 1)
        let evening = makeSession(daysAgo: 1)
        let other = makeSession(daysAgo: 3)

        let dayCount = StatsAggregator.climbingDayCount(
            of: [morning, evening, other], calendar: calendar
        )

        #expect(dayCount == 2)
    }

    @Test func sendCountPerGradeIgnoresProjects() {
        let session = makeSession(daysAgo: 0)
        addAttempt(session, grade: .blue, result: .flash)
        addAttempt(session, grade: .blue, result: .send)
        addAttempt(session, grade: .blue, result: .project)

        let counts = StatsAggregator.sendCountPerGrade(of: [session])

        #expect(counts[.blue] == 2)
        #expect(counts[.red] == nil)
    }

    @Test func hardestSendPicksHighestGrade() {
        let session = makeSession(daysAgo: 0)
        addAttempt(session, grade: .black, result: .send)
        addAttempt(session, grade: .white, result: .project)
        addAttempt(session, grade: .red, result: .flash)

        let hardest = StatsAggregator.hardestSend(of: [session])

        #expect(hardest?.colorGrade == .black)
    }

    @Test func proudestSendBreaksTiesByAttemptCount() {
        let session = makeSession(daysAgo: 0)
        addAttempt(session, grade: .black, attempts: 2, result: .send)
        addAttempt(session, grade: .black, attempts: 9, result: .send)

        let proudest = StatsAggregator.proudestSend(of: [session])

        #expect(proudest?.attemptCount == 9)
    }

    @Test func sendRatePerStyleComputesPerStyleRatio() {
        let session = makeSession(daysAgo: 0)
        addAttempt(session, grade: .red, styles: [.sloper], result: .send)
        addAttempt(session, grade: .red, styles: [.sloper], result: .project)
        addAttempt(session, grade: .red, styles: [.crimp], result: .flash)

        let rates = StatsAggregator.sendRatePerStyle(of: [session])

        #expect(abs((rates[.sloper] ?? 0) - 0.5) < 0.001)
        #expect(abs((rates[.crimp] ?? 0) - 1.0) < 0.001)
    }

    @Test func weeklyStreakCountsConsecutiveWeeks() {
        let referenceDate = Date.now
        let thisWeek = makeSession(daysAgo: 0, referenceDate: referenceDate)
        let lastWeek = makeSession(daysAgo: 7, referenceDate: referenceDate)
        let threeWeeksAgo = makeSession(daysAgo: 21, referenceDate: referenceDate)

        let streak = StatsAggregator.weeklyStreak(
            of: [thisWeek, lastWeek, threeWeeksAgo],
            calendar: calendar, referenceDate: referenceDate
        )

        #expect(streak == 2)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL — `StatsAggregator` not found.

- [ ] **Step 3: Implement**

`BoulderTracker/Stats/StatsPeriod.swift`:

```swift
import Foundation

enum StatsPeriod: String, CaseIterable, Identifiable {
    case month, threeMonths, year, all

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .month: "Month"
        case .threeMonths: "3 Months"
        case .year: "Year"
        case .all: "All"
        }
    }

    func interval(endingAt referenceDate: Date, calendar: Calendar) -> DateInterval? {
        let monthsBack: Int
        switch self {
        case .month: monthsBack = 1
        case .threeMonths: monthsBack = 3
        case .year: monthsBack = 12
        case .all: return nil
        }
        guard let start = calendar.date(byAdding: .month, value: -monthsBack, to: referenceDate) else {
            return nil
        }
        return DateInterval(start: start, end: referenceDate)
    }
}
```

`BoulderTracker/Stats/StatsSummary.swift`:

```swift
import Foundation

struct StatsSummary: Equatable {
    var sessionCount = 0
    var totalDuration: TimeInterval = 0
    var problemCount = 0
    var sendCount = 0
    var attemptCount = 0
    var flashCount = 0

    var completionRate: Double {
        problemCount == 0 ? 0 : Double(sendCount) / Double(problemCount)
    }

    var flashRate: Double {
        problemCount == 0 ? 0 : Double(flashCount) / Double(problemCount)
    }
}
```

`BoulderTracker/Stats/StatsAggregator.swift`:

```swift
import Foundation

enum StatsAggregator {
    static func sessions(_ sessions: [Session], in interval: DateInterval?) -> [Session] {
        guard let interval else { return sessions }
        return sessions.filter { interval.contains($0.startTime) }
    }

    static func summary(of sessions: [Session]) -> StatsSummary {
        var summary = StatsSummary()
        summary.sessionCount = sessions.count
        summary.totalDuration = sessions.reduce(0) { $0 + $1.duration }
        let attempts = allAttempts(in: sessions)
        summary.problemCount = attempts.count
        summary.sendCount = attempts.filter { $0.result.countsAsSend }.count
        summary.flashCount = attempts.filter { $0.result == .flash }.count
        summary.attemptCount = attempts.reduce(0) { $0 + $1.attemptCount }
        return summary
    }

    static func climbingDayCount(of sessions: [Session], calendar: Calendar) -> Int {
        Set(sessions.map { calendar.startOfDay(for: $0.startTime) }).count
    }

    static func sendCountPerGrade(of sessions: [Session]) -> [ColorGrade: Int] {
        let sends = allAttempts(in: sessions).filter { $0.result.countsAsSend }
        return Dictionary(grouping: sends, by: \.colorGrade).mapValues(\.count)
    }

    static func sendRatePerStyle(of sessions: [Session]) -> [RouteStyle: Double] {
        var totals: [RouteStyle: Int] = [:]
        var sends: [RouteStyle: Int] = [:]
        for attempt in allAttempts(in: sessions) {
            for style in attempt.styles {
                totals[style, default: 0] += 1
                if attempt.result.countsAsSend {
                    sends[style, default: 0] += 1
                }
            }
        }
        return totals.reduce(into: [:]) { rates, entry in
            rates[entry.key] = Double(sends[entry.key] ?? 0) / Double(entry.value)
        }
    }

    static func hardestSend(of sessions: [Session]) -> ProblemAttempt? {
        allAttempts(in: sessions)
            .filter { $0.result.countsAsSend }
            .max { $0.colorGrade < $1.colorGrade }
    }

    static func hardestFlash(of sessions: [Session]) -> ProblemAttempt? {
        allAttempts(in: sessions)
            .filter { $0.result == .flash }
            .max { $0.colorGrade < $1.colorGrade }
    }

    static func weeklyStreak(of sessions: [Session], calendar: Calendar, referenceDate: Date) -> Int {
        let sessionWeeks = Set(sessions.compactMap { session in
            calendar.dateInterval(of: .weekOfYear, for: session.startTime)?.start
        })
        var streak = 0
        var cursor = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start
        while let week = cursor, sessionWeeks.contains(week) {
            streak += 1
            cursor = calendar.date(byAdding: .weekOfYear, value: -1, to: week)
        }
        return streak
    }

    static func proudestSend(of sessions: [Session]) -> ProblemAttempt? {
        allAttempts(in: sessions)
            .filter { $0.result.countsAsSend }
            .max { lhs, rhs in
                if lhs.colorGrade != rhs.colorGrade { return lhs.colorGrade < rhs.colorGrade }
                return lhs.attemptCount < rhs.attemptCount
            }
    }

    private static func allAttempts(in sessions: [Session]) -> [ProblemAttempt] {
        sessions.flatMap(\.attempts)
    }
}
```

- [ ] **Step 4: Regenerate, run tests, verify pass**

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add StatsAggregator with period filtering and streaks"
```

---

### Task 6: AchievementEngine

**Files:**
- Create: `BoulderTracker/Services/AchievementDefinition.swift`
- Create: `BoulderTracker/Services/AchievementEngine.swift`
- Test: `BoulderTrackerTests/AchievementEngineTests.swift`

**Interfaces:**
- Consumes: `Session`, `ProblemAttempt`, enums, `StatsAggregator.weeklyStreak`.
- Produces:
  - `struct AchievementDefinition: Identifiable` — `let id: String`, `let title: String`, `let detail: String`, `let symbolName: String`, `let isSatisfied: ([Session]) -> Bool`.
  - `enum AchievementEngine` — `static let definitions: [AchievementDefinition]` (all ~24), `static func newlyUnlocked(sessions: [Session], alreadyUnlocked: Set<String>) -> [AchievementDefinition]`.
  - ID scheme (stable, referenced by Profile UI): `first-session`, `first-send-green` … `first-send-yellow`, `first-flash`, `first-photo`, `first-partner-session`, `sends-10`, `sends-50`, `sends-100`, `sends-500`, `sessions-10`, `sessions-50`, `sessions-100`, `weekly-streak-5`, `three-per-week-4-weeks`, `flash-10-blues`, `five-styles`, `project-attempts-100`, `night-owl`, `marathon`, `globetrotter`.

- [ ] **Step 1: Write failing tests** `BoulderTrackerTests/AchievementEngineTests.swift`

```swift
import Testing
import Foundation
@testable import BoulderTracker

@MainActor
struct AchievementEngineTests {
    private func makeFinishedSession(hoursLong: Double = 1.5,
                                     endHour: Int = 18) -> Session {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        components.hour = endHour
        let end = Calendar.current.date(from: components)!
        let session = Session(
            startTime: end.addingTimeInterval(-hoursLong * 3600),
            gym: nil, partners: []
        )
        session.endTime = end
        return session
    }

    @Test func firstSessionUnlocksAfterOneSession() {
        let unlocked = AchievementEngine.newlyUnlocked(
            sessions: [makeFinishedSession()], alreadyUnlocked: []
        )
        #expect(unlocked.contains { $0.id == "first-session" })
    }

    @Test func alreadyUnlockedAreNotReturnedAgain() {
        let unlocked = AchievementEngine.newlyUnlocked(
            sessions: [makeFinishedSession()], alreadyUnlocked: ["first-session"]
        )
        #expect(!unlocked.contains { $0.id == "first-session" })
    }

    @Test func firstSendPerColorUnlocks() {
        let session = makeFinishedSession()
        session.attempts.append(ProblemAttempt(
            colorGrade: .black, styles: [], attemptCount: 4, result: .send
        ))
        let unlocked = AchievementEngine.newlyUnlocked(sessions: [session], alreadyUnlocked: [])
        #expect(unlocked.contains { $0.id == "first-send-black" })
        #expect(!unlocked.contains { $0.id == "first-send-yellow" })
    }

    @Test func marathonRequiresTwoHours() {
        let short = makeFinishedSession(hoursLong: 1.9)
        let long = makeFinishedSession(hoursLong: 2.1)
        #expect(!AchievementEngine.newlyUnlocked(sessions: [short], alreadyUnlocked: [])
            .contains { $0.id == "marathon" })
        #expect(AchievementEngine.newlyUnlocked(sessions: [long], alreadyUnlocked: [])
            .contains { $0.id == "marathon" })
    }

    @Test func nightOwlRequiresEndAfterNine() {
        let evening = makeFinishedSession(endHour: 22)
        let unlocked = AchievementEngine.newlyUnlocked(sessions: [evening], alreadyUnlocked: [])
        #expect(unlocked.contains { $0.id == "night-owl" })
    }

    @Test func flashTenBluesUnlocks() {
        let session = makeFinishedSession()
        for _ in 0..<10 {
            session.attempts.append(ProblemAttempt(
                colorGrade: .blue, styles: [], attemptCount: 1, result: .flash
            ))
        }
        let unlocked = AchievementEngine.newlyUnlocked(sessions: [session], alreadyUnlocked: [])
        #expect(unlocked.contains { $0.id == "flash-10-blues" })
    }

    @Test func fiveStylesRequiresSendsInFiveDistinctStyles() {
        let session = makeFinishedSession()
        let styles: [RouteStyle] = [.dyno, .sloper, .crimp, .overhang, .slab]
        for style in styles {
            session.attempts.append(ProblemAttempt(
                colorGrade: .green, styles: [style], attemptCount: 1, result: .send
            ))
        }
        let unlocked = AchievementEngine.newlyUnlocked(sessions: [session], alreadyUnlocked: [])
        #expect(unlocked.contains { $0.id == "five-styles" })
    }

    @Test func globetrotterRequiresThreeGyms() {
        let sessions = ["A", "B", "C"].map { name in
            let session = makeFinishedSession()
            session.gym = Gym(name: name)
            return session
        }
        let unlocked = AchievementEngine.newlyUnlocked(sessions: sessions, alreadyUnlocked: [])
        #expect(unlocked.contains { $0.id == "globetrotter" })
    }

    @Test func allDefinitionIDsAreUnique() {
        let ids = AchievementEngine.definitions.map(\.id)
        #expect(Set(ids).count == ids.count)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL — `AchievementEngine` not found.

- [ ] **Step 3: Implement**

`BoulderTracker/Services/AchievementDefinition.swift`:

```swift
import Foundation

struct AchievementDefinition: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbolName: String
    let isSatisfied: ([Session]) -> Bool
}
```

`BoulderTracker/Services/AchievementEngine.swift`:

```swift
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

    static let definitions: [AchievementDefinition] =
        firstDefinitions + volumeDefinitions + streakDefinitions
        + skillDefinitions + funDefinitions

    private static var firstDefinitions: [AchievementDefinition] {
        var items = [
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
        for grade in ColorGrade.allCases {
            items.append(AchievementDefinition(
                id: "first-send-\(grade.displayName.lowercased())",
                title: "\(grade.displayName) Breaker",
                detail: "Send your first \(grade.displayName.lowercased()) problem",
                symbolName: "checkmark.seal.fill"
            ) { sessions in
                allAttempts(sessions).contains { $0.colorGrade == grade && $0.result.countsAsSend }
            })
        }
        return items
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
```

Note: `AchievementEngine.swift` groups definitions by category via private computed
arrays to stay under function-size budgets; the file may approach 200 LOC — acceptable, single concern.

- [ ] **Step 4: Regenerate, run tests, verify pass**

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add AchievementEngine with 24 unlock rules"
```

---

### Task 7: HealthKit writer

**Files:**
- Create: `BoulderTracker/Services/WorkoutWriting.swift`
- Create: `BoulderTracker/Services/HealthKitWorkoutWriter.swift`
- Test: `BoulderTrackerTests/FakeWorkoutWriter.swift` (test double used by later UI tasks; no HealthKit unit tests — real store untestable in CI)

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `protocol WorkoutWriting: Sendable { func requestAuthorization() async throws; func saveClimbingWorkout(start: Date, end: Date) async throws -> UUID; func deleteClimbingWorkout(id: UUID) async throws }`
  - `final class HealthKitWorkoutWriter: WorkoutWriting` — real implementation over `HKHealthStore`.
  - `final class FakeWorkoutWriter: WorkoutWriting` (test target) — records calls, returns fixed UUID.

- [ ] **Step 1: Write protocol** `BoulderTracker/Services/WorkoutWriting.swift`

```swift
import Foundation

protocol WorkoutWriting: Sendable {
    func requestAuthorization() async throws
    func saveClimbingWorkout(start: Date, end: Date) async throws -> UUID
    func deleteClimbingWorkout(id: UUID) async throws
}
```

- [ ] **Step 2: Write real implementation** `BoulderTracker/Services/HealthKitWorkoutWriter.swift`

```swift
import Foundation
import HealthKit

final class HealthKitWorkoutWriter: WorkoutWriting {
    private let store = HKHealthStore()

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try await store.requestAuthorization(
            toShare: [HKObjectType.workoutType()], read: []
        )
    }

    func saveClimbingWorkout(start: Date, end: Date) async throws -> UUID {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .climbing
        configuration.locationType = .indoor
        let builder = HKWorkoutBuilder(
            healthStore: store, configuration: configuration, device: .local()
        )
        try await builder.beginCollection(at: start)
        try await builder.endCollection(at: end)
        guard let workout = try await builder.finishWorkout() else {
            throw WorkoutWriteFailure.builderReturnedNoWorkout
        }
        return workout.uuid
    }

    func deleteClimbingWorkout(id: UUID) async throws {
        let predicate = HKQuery.predicateForObject(with: id)
        let samples = try await queryWorkouts(matching: predicate)
        guard let workout = samples.first else { return }
        try await store.delete(workout)
    }

    private func queryWorkouts(matching predicate: NSPredicate) async throws -> [HKSample] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(), predicate: predicate,
                limit: 1, sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples ?? [])
                }
            }
            store.execute(query)
        }
    }
}

enum WorkoutWriteFailure: Error {
    case builderReturnedNoWorkout
}
```

- [ ] **Step 3: Write fake** `BoulderTrackerTests/FakeWorkoutWriter.swift`

```swift
import Foundation
@testable import BoulderTracker

final class FakeWorkoutWriter: WorkoutWriting, @unchecked Sendable {
    private(set) var savedIntervals: [(start: Date, end: Date)] = []
    private(set) var deletedIDs: [UUID] = []
    let fixedWorkoutID = UUID()

    func requestAuthorization() async throws {}

    func saveClimbingWorkout(start: Date, end: Date) async throws -> UUID {
        savedIntervals.append((start, end))
        return fixedWorkoutID
    }

    func deleteClimbingWorkout(id: UUID) async throws {
        deletedIDs.append(id)
    }
}
```

- [ ] **Step 4: Regenerate, build (no new tests — compile check)**

```bash
xcodegen generate
xcodebuild build -project BoulderTracker.xcodeproj -scheme BoulderTracker -destination "platform=iOS Simulator,name=iPhone 17 Pro" -quiet
```

Expected: build succeeds. Then run full test suite — still green.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add HealthKit workout writer behind WorkoutWriting protocol"
```

---

### Task 8: Session lifecycle service

Glues save-time concerns: end session → HealthKit write → achievement check. Keeps views dumb.

**Files:**
- Create: `BoulderTracker/Services/SessionCompletion.swift`
- Test: `BoulderTrackerTests/SessionCompletionTests.swift`

**Interfaces:**
- Consumes: `WorkoutWriting` (Task 7), `AchievementEngine` (Task 6), models (Task 3).
- Produces:
  - `struct SessionCompletionOutcome` — `let newAchievements: [AchievementDefinition]`, `let workoutSaved: Bool`.
  - `struct SessionCompletion` — `init(workoutWriter: WorkoutWriting)`,
    `func finish(_ session: Session, endTime: Date, allSessions: [Session], unlockedIDs: Set<String>) async -> SessionCompletionOutcome`.
    Behavior: sets `session.endTime`; tries workout save (stores UUID on session, `workoutSaved` false on any error — never throws); evaluates achievements over `allSessions`.
  - `func discard(_ session: Session) async` is NOT here — deletion handled by callers via ModelContext; workout deletion helper: `func deleteWorkoutIfPresent(for session: Session) async`.

- [ ] **Step 1: Write failing tests** `BoulderTrackerTests/SessionCompletionTests.swift`

```swift
import Testing
import Foundation
@testable import BoulderTracker

@MainActor
struct SessionCompletionTests {
    @Test func finishSetsEndTimeAndSavesWorkout() async {
        let writer = FakeWorkoutWriter()
        let completion = SessionCompletion(workoutWriter: writer)
        let session = Session(startTime: .now.addingTimeInterval(-3600), gym: nil, partners: [])

        let outcome = await completion.finish(
            session, endTime: .now, allSessions: [session], unlockedIDs: []
        )

        #expect(session.endTime != nil)
        #expect(session.healthKitWorkoutID == writer.fixedWorkoutID)
        #expect(outcome.workoutSaved)
        #expect(outcome.newAchievements.contains { $0.id == "first-session" })
    }

    @Test func workoutFailureDoesNotBlockCompletion() async {
        let completion = SessionCompletion(workoutWriter: ThrowingWorkoutWriter())
        let session = Session(startTime: .now.addingTimeInterval(-3600), gym: nil, partners: [])

        let outcome = await completion.finish(
            session, endTime: .now, allSessions: [session], unlockedIDs: []
        )

        #expect(session.endTime != nil)
        #expect(!outcome.workoutSaved)
        #expect(session.healthKitWorkoutID == nil)
    }
}

private final class ThrowingWorkoutWriter: WorkoutWriting, @unchecked Sendable {
    struct Refused: Error {}
    func requestAuthorization() async throws { throw Refused() }
    func saveClimbingWorkout(start: Date, end: Date) async throws -> UUID { throw Refused() }
    func deleteClimbingWorkout(id: UUID) async throws { throw Refused() }
}
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement** `BoulderTracker/Services/SessionCompletion.swift`

```swift
import Foundation

struct SessionCompletionOutcome: Identifiable {
    let id = UUID()
    let newAchievements: [AchievementDefinition]
    let workoutSaved: Bool
}

struct SessionCompletion {
    private let workoutWriter: WorkoutWriting

    init(workoutWriter: WorkoutWriting) {
        self.workoutWriter = workoutWriter
    }

    @MainActor
    func finish(_ session: Session, endTime: Date, allSessions: [Session],
                unlockedIDs: Set<String>) async -> SessionCompletionOutcome {
        session.endTime = endTime
        let workoutSaved = await saveWorkout(for: session)
        let newAchievements = AchievementEngine.newlyUnlocked(
            sessions: allSessions, alreadyUnlocked: unlockedIDs
        )
        return SessionCompletionOutcome(
            newAchievements: newAchievements, workoutSaved: workoutSaved
        )
    }

    @MainActor
    func deleteWorkoutIfPresent(for session: Session) async {
        guard let workoutID = session.healthKitWorkoutID else { return }
        do {
            try await workoutWriter.deleteClimbingWorkout(id: workoutID)
        } catch {
            // Best-effort: local delete proceeds even when Health is unreachable.
            session.healthKitWorkoutID = nil
        }
    }

    @MainActor
    private func saveWorkout(for session: Session) async -> Bool {
        guard let end = session.endTime else { return false }
        do {
            let workoutID = try await workoutWriter.saveClimbingWorkout(
                start: session.startTime, end: end
            )
            session.healthKitWorkoutID = workoutID
            return true
        } catch {
            return false
        }
    }
}
```

Note on the empty-looking catch in `deleteWorkoutIfPresent`: it mutates state (clears the ID) — not a swallowed exception.

- [ ] **Step 4: Regenerate, run tests, verify pass**

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add SessionCompletion service gluing HealthKit and achievements"
```

---

### Task 9: Home tab — overview + session entry points

**Files:**
- Create: `BoulderTracker/Home/HomeView.swift`
- Create: `BoulderTracker/Home/OverviewSection.swift`
- Create: `BoulderTracker/Home/HighlightCard.swift`
- Create: `BoulderTracker/Home/RecentSessionsList.swift`
- Create: `BoulderTracker/Home/StartSessionSheet.swift`
- Modify: `BoulderTracker/App/RootTabView.swift` (home placeholder → `HomeView()`)

**Interfaces:**
- Consumes: `StatsAggregator`, `StatsPeriod`, models, `ColorGrade.displayColor`, `PhotoStore`.
- Produces: `HomeView` (queries sessions via `@Query`, shows overview or `LiveSessionView` from Task 10 — until Task 10 lands, live state shows `SessionInProgressPlaceholder` text). `StartSessionSheet` creates a `Session` with chosen gym/partners and inserts it. Duration formatting helper `SessionDurationFormat.string(from: TimeInterval) -> String` in `BoulderTracker/Home/SessionDurationFormat.swift`.

- [ ] **Step 1: Implement duration formatter with test**

Test in `BoulderTrackerTests/SessionDurationFormatTests.swift`:

```swift
import Testing
@testable import BoulderTracker

struct SessionDurationFormatTests {
    @Test func formatsHoursMinutesSeconds() {
        #expect(SessionDurationFormat.string(from: 3 * 3600 + 21 * 60 + 5) == "3:21:05")
        #expect(SessionDurationFormat.string(from: 45 * 60) == "0:45:00")
    }
}
```

Run: FAIL. Then implement `BoulderTracker/Home/SessionDurationFormat.swift`:

```swift
import Foundation

enum SessionDurationFormat {
    static func string(from duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }
}
```

Run: PASS.

- [ ] **Step 2: Implement OverviewSection** `BoulderTracker/Home/OverviewSection.swift`

```swift
import SwiftUI

struct OverviewSection: View {
    let sessions: [Session]

    private var summary: StatsSummary { StatsAggregator.summary(of: sessions) }
    private var climbingDays: Int {
        StatsAggregator.climbingDayCount(of: sessions, calendar: .current)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            greeting
            totalTimeCard
            metricRow
        }
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Liam,")
                .font(.largeTitle.bold())
                .foregroundStyle(.green)
            Text("\(climbingDays) climbing days in the last 3 months")
                .font(.headline)
        }
    }

    private var totalTimeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Total climb time", systemImage: "stopwatch")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(SessionDurationFormat.string(from: summary.totalDuration))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .glassEffect(in: .rect(cornerRadius: 20))
    }

    private var metricRow: some View {
        HStack {
            MetricTile(label: "Sent", valueText: "\(summary.sendCount)")
            MetricTile(label: "Attempts", valueText: "\(summary.attemptCount)")
            MetricTile(
                label: "Completion",
                valueText: summary.completionRate.formatted(.percent.precision(.fractionLength(0)))
            )
        }
    }
}

struct MetricTile: View {
    let label: String
    let valueText: String

    var body: some View {
        VStack(spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(valueText).font(.title2.bold()).monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .glassEffect(in: .rect(cornerRadius: 16))
    }
}
```

- [ ] **Step 3: Implement HighlightCard** `BoulderTracker/Home/HighlightCard.swift`

```swift
import SwiftUI

struct HighlightCard: View {
    let sessions: [Session]
    private let photoStore = PhotoStore.makeDefault()

    private var proudest: ProblemAttempt? { StatsAggregator.proudestSend(of: sessions) }

    var body: some View {
        if let attempt = proudest {
            VStack(alignment: .leading, spacing: 8) {
                Text("Proudest send")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                proudestDescription(for: attempt)
                photoThumbnail(for: attempt)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .glassEffect(in: .rect(cornerRadius: 20))
        }
    }

    private func proudestDescription(for attempt: ProblemAttempt) -> some View {
        let gymName = attempt.session?.gym?.name ?? "your gym"
        return (
            Text("At \(gymName) you sent a ")
            + Text(attempt.colorGrade.displayName)
                .foregroundStyle(attempt.colorGrade.displayColor)
                .bold()
            + Text(" problem after \(attempt.attemptCount) attempts!")
        )
        .font(.headline)
    }

    @ViewBuilder
    private func photoThumbnail(for attempt: ProblemAttempt) -> some View {
        if let filename = attempt.photoFilename,
           let imageData = photoStore.loadPhoto(named: filename),
           let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 140)
                .clipShape(.rect(cornerRadius: 12))
        }
    }
}
```

- [ ] **Step 4: Implement RecentSessionsList** `BoulderTracker/Home/RecentSessionsList.swift`

```swift
import SwiftUI

struct RecentSessionsList: View {
    let sessions: [Session]
    private static let recentLimit = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent sessions").font(.headline)
            ForEach(sessions.prefix(Self.recentLimit)) { session in
                NavigationLink(value: session.persistentModelID) {
                    SessionRow(session: session)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct SessionRow: View {
    let session: Session

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(session.startTime, format: .dateTime.weekday(.wide).day().month())
                    .font(.subheadline.bold())
                Text(session.gym?.name ?? "Unknown gym")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(session.attempts.filter { $0.result.countsAsSend }.count) sends")
                .font(.caption.bold())
        }
        .padding(.vertical, 8)
    }
}
```

- [ ] **Step 5: Implement StartSessionSheet** `BoulderTracker/Home/StartSessionSheet.swift`

```swift
import SwiftUI
import SwiftData

struct StartSessionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Gym.name) private var gyms: [Gym]
    @Query(sort: \Partner.name) private var allPartners: [Partner]
    @State private var selectedGym: Gym?
    @State private var selectedPartners: Set<PersistentIdentifier> = []

    var body: some View {
        NavigationStack {
            Form {
                Picker("Gym", selection: $selectedGym) {
                    ForEach(gyms) { gym in
                        Text(gym.name).tag(Optional(gym))
                    }
                }
                Section("Partners") {
                    ForEach(allPartners) { partner in
                        Toggle(partner.name, isOn: partnerBinding(for: partner))
                    }
                }
            }
            .navigationTitle("Start Session")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start", action: startSession)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { selectedGym = gyms.first { $0.isDefault } ?? gyms.first }
        }
    }

    private func partnerBinding(for partner: Partner) -> Binding<Bool> {
        Binding(
            get: { selectedPartners.contains(partner.persistentModelID) },
            set: { isSelected in
                if isSelected {
                    selectedPartners.insert(partner.persistentModelID)
                } else {
                    selectedPartners.remove(partner.persistentModelID)
                }
            }
        )
    }

    private func startSession() {
        let partners = allPartners.filter { selectedPartners.contains($0.persistentModelID) }
        let session = Session(startTime: .now, gym: selectedGym, partners: partners)
        modelContext.insert(session)
        dismiss()
    }
}
```

- [ ] **Step 6: Implement HomeView** `BoulderTracker/Home/HomeView.swift`

```swift
import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: \Session.startTime, order: .reverse) private var sessions: [Session]
    @State private var showingStartSheet = false
    @State private var showingRetroForm = false

    private var liveSession: Session? { sessions.first { $0.isLive } }
    private var finishedSessions: [Session] { sessions.filter { !$0.isLive } }
    private var overviewSessions: [Session] {
        let interval = StatsPeriod.threeMonths.interval(endingAt: .now, calendar: .current)
        return StatsAggregator.sessions(finishedSessions, in: interval)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let liveSession {
                    LiveSessionView(session: liveSession)
                } else {
                    overviewContent
                }
            }
            .navigationTitle("Boulder Tracker")
            .navigationDestination(for: PersistentIdentifier.self) { sessionID in
                SessionDetailView(sessionID: sessionID)
            }
        }
    }

    private var overviewContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                OverviewSection(sessions: overviewSessions)
                HighlightCard(sessions: overviewSessions)
                startButtons
                RecentSessionsList(sessions: finishedSessions)
            }
            .padding()
        }
        .sheet(isPresented: $showingStartSheet) { StartSessionSheet() }
        .sheet(isPresented: $showingRetroForm) { RetroSessionForm() }
    }

    private var startButtons: some View {
        VStack(spacing: 12) {
            Button {
                showingStartSheet = true
            } label: {
                Label("Start Session", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.glassProminent)
            .tint(.green)

            Button("Add Past Session") { showingRetroForm = true }
                .buttonStyle(.glass)
        }
    }
}
```

Until Tasks 10–12 land, add temporary minimal placeholder types in ONE file
`BoulderTracker/Home/PendingScreens.swift` (deleted as real ones arrive):

```swift
import SwiftUI
import SwiftData

// Placeholders replaced by Tasks 10-12. Delete each when the real view lands.
struct LiveSessionView: View {
    let session: Session
    var body: some View { Text("Session in progress") }
}

struct RetroSessionForm: View {
    var body: some View { Text("Retro form") }
}

struct SessionDetailView: View {
    let sessionID: PersistentIdentifier
    var body: some View { Text("Session detail") }
}
```

- [ ] **Step 7: Wire into RootTabView**

Replace home tab placeholder: `Tab("Home", systemImage: "figure.climbing", value: .home) { HomeView() }`.

- [ ] **Step 8: Regenerate, run full test suite, build**

Expected: tests pass, app builds.

- [ ] **Step 9: Manual verify on simulator**

Launch app in simulator. Check: greeting renders, zero-state metrics show 0, Start Session opens sheet with seeded gym preselected, starting creates live placeholder.

- [ ] **Step 10: Commit**

```bash
git add -A && git commit -m "feat: add Home tab with overview, highlight card, and session entry points"
```

---

### Task 10: Live session + quick-add + summary

**Files:**
- Create: `BoulderTracker/Home/LiveSessionView.swift` (replaces placeholder)
- Create: `BoulderTracker/Home/QuickAddProblemSheet.swift`
- Create: `BoulderTracker/Home/SessionSummaryView.swift`
- Create: `BoulderTracker/Home/RoutePhotoPicker.swift`
- Modify: `BoulderTracker/Home/PendingScreens.swift` (remove LiveSessionView placeholder)

**Interfaces:**
- Consumes: `SessionCompletion` (Task 8), `HealthKitWorkoutWriter` (Task 7), `PhotoStore` (Task 4), models, `SessionDurationFormat`.
- Produces: full live-session flow. `QuickAddProblemSheet(session:)` appends `ProblemAttempt`s. `SessionSummaryView(session:outcome:)` shown after finish, lists new achievements.

- [ ] **Step 1: Implement LiveSessionView**

```swift
import SwiftUI
import SwiftData

struct LiveSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Session.startTime) private var allSessions: [Session]
    @Query private var unlockedAchievements: [Achievement]
    let session: Session

    @State private var showingQuickAdd = false
    @State private var summaryOutcome: SessionCompletionOutcome?
    @State private var currentDate = Date.now

    private let clockTick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let completion = SessionCompletion(workoutWriter: HealthKitWorkoutWriter())

    var body: some View {
        VStack(spacing: 24) {
            timerHeader
            colorTally
            Spacer()
            actionButtons
        }
        .padding()
        .onReceive(clockTick) { now in currentDate = now }
        .sheet(isPresented: $showingQuickAdd) { QuickAddProblemSheet(session: session) }
        .sheet(item: $summaryOutcome) { outcome in
            SessionSummaryView(session: session, outcome: outcome)
        }
    }

    private var timerHeader: some View {
        VStack(spacing: 4) {
            Text("Session running")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(SessionDurationFormat.string(
                from: currentDate.timeIntervalSince(session.startTime)
            ))
            .font(.system(size: 48, weight: .bold, design: .rounded))
            .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .glassEffect(in: .rect(cornerRadius: 24))
    }

    private var colorTally: some View {
        HStack(spacing: 12) {
            ForEach(ColorGrade.allCases) { grade in
                let count = session.attempts.filter { $0.colorGrade == grade }.count
                VStack(spacing: 2) {
                    Circle().fill(grade.displayColor).frame(width: 22, height: 22)
                    Text("\(count)").font(.caption.bold()).monospacedDigit()
                }
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                showingQuickAdd = true
            } label: {
                Label("Add Problem", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.glassProminent)
            .tint(.green)

            Button("End Session", role: .destructive, action: endSession)
                .buttonStyle(.glass)
        }
    }

    private func endSession() {
        Task {
            let unlockedIDs = Set(unlockedAchievements.map(\.achievementID))
            let outcome = await completion.finish(
                session, endTime: .now,
                allSessions: allSessions, unlockedIDs: unlockedIDs
            )
            for achievement in outcome.newAchievements {
                modelContext.insert(Achievement(achievementID: achievement.id))
            }
            try? modelContext.save()
            summaryOutcome = outcome
        }
    }
}

```

`SessionCompletionOutcome` is already `Identifiable` (UUID id from Task 8), so `.sheet(item:)` works directly.

- [ ] **Step 2: Implement QuickAddProblemSheet**

```swift
import SwiftUI
import PhotosUI

struct QuickAddProblemSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let session: Session

    @State private var selectedGrade: ColorGrade = .green
    @State private var selectedStyles: Set<RouteStyle> = []
    @State private var attemptCount = 1
    @State private var result: AttemptResult = .flash
    @State private var photoData: Data?
    private let photoStore = PhotoStore.makeDefault()

    var body: some View {
        NavigationStack {
            Form {
                gradeSection
                styleSection
                attemptSection
                RoutePhotoPicker(photoData: $photoData)
            }
            .navigationTitle("Add Problem")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: saveProblem)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var gradeSection: some View {
        Section("Grade") {
            HStack(spacing: 10) {
                ForEach(ColorGrade.allCases) { grade in
                    Circle()
                        .fill(grade.displayColor)
                        .frame(width: 40, height: 40)
                        .overlay {
                            if grade == selectedGrade {
                                Circle().strokeBorder(.primary, lineWidth: 3)
                            }
                        }
                        .onTapGesture { selectedGrade = grade }
                        .accessibilityLabel(grade.displayName)
                }
            }
        }
    }

    private var styleSection: some View {
        Section("Styles") {
            FlowingStyleChips(selectedStyles: $selectedStyles)
        }
    }

    private var attemptSection: some View {
        Section("Result") {
            Picker("Result", selection: $result) {
                ForEach(AttemptResult.allCases) { attemptResult in
                    Text(attemptResult.displayName).tag(attemptResult)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: result) { _, newResult in
                if newResult == .flash { attemptCount = 1 }
            }
            Stepper("Attempts: \(attemptCount)", value: $attemptCount, in: 1...99)
                .disabled(result == .flash)
        }
    }

    private func saveProblem() {
        let attempt = ProblemAttempt(
            colorGrade: selectedGrade, styles: Array(selectedStyles),
            attemptCount: attemptCount, result: result
        )
        if let photoData {
            attempt.photoFilename = try? photoStore.savePhoto(photoData)
        }
        session.attempts.append(attempt)
        try? modelContext.save()
        dismiss()
    }
}

struct FlowingStyleChips: View {
    @Binding var selectedStyles: Set<RouteStyle>
    private let columns = [GridItem(.adaptive(minimum: 100))]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(RouteStyle.allCases) { style in
                let isSelected = selectedStyles.contains(style)
                Text(style.displayName)
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        isSelected ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.15),
                        in: .capsule
                    )
                    .onTapGesture {
                        if isSelected {
                            selectedStyles.remove(style)
                        } else {
                            selectedStyles.insert(style)
                        }
                    }
            }
        }
    }
}
```

- [ ] **Step 3: Implement RoutePhotoPicker**

```swift
import SwiftUI
import PhotosUI

struct RoutePhotoPicker: View {
    @Binding var photoData: Data?
    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        Section("Photo") {
            PhotosPicker(selection: $selectedItem, matching: .images) {
                Label(
                    photoData == nil ? "Add route photo" : "Change photo",
                    systemImage: "camera"
                )
            }
            if let photoData, let image = UIImage(data: photoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 160)
                    .clipShape(.rect(cornerRadius: 12))
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                photoData = try? await newItem?.loadTransferable(type: Data.self)
            }
        }
    }
}
```

- [ ] **Step 4: Implement SessionSummaryView**

```swift
import SwiftUI

struct SessionSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    let session: Session
    let outcome: SessionCompletionOutcome

    private var summary: StatsSummary { StatsAggregator.summary(of: [session]) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text(SessionDurationFormat.string(from: session.duration))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                    HStack {
                        MetricTile(label: "Problems", valueText: "\(summary.problemCount)")
                        MetricTile(label: "Sends", valueText: "\(summary.sendCount)")
                        MetricTile(
                            label: "Flash rate",
                            valueText: summary.flashRate.formatted(.percent.precision(.fractionLength(0)))
                        )
                    }
                    achievementList
                    if !outcome.workoutSaved {
                        Text("Couldn't save to Apple Health — session saved locally.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Session Complete")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var achievementList: some View {
        if !outcome.newAchievements.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("New achievements").font(.headline)
                ForEach(outcome.newAchievements) { achievement in
                    Label(achievement.title, systemImage: achievement.symbolName)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .glassEffect(in: .rect(cornerRadius: 16))
        }
    }
}
```

- [ ] **Step 5: Remove LiveSessionView placeholder from PendingScreens.swift, regenerate, test, build**

Full suite green + build succeeds.

- [ ] **Step 6: Manual verify on simulator**

Start session → add problem (grade, styles, stepper, result) → tally updates → end session → summary shows counts + "first-session" achievement → Home returns to overview with session in recent list. Relaunch app mid-session → live view restored (persistence via endTime nil).

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "feat: add live session flow with quick-add and summary"
```

---

### Task 11: Retro session form + session detail

**Files:**
- Create: `BoulderTracker/Home/RetroSessionForm.swift` (replaces placeholder)
- Create: `BoulderTracker/Calendar/SessionDetailView.swift` (replaces placeholder; lives in Calendar folder per spec)
- Modify: `BoulderTracker/Home/PendingScreens.swift` — delete file entirely
- Modify: `BoulderTracker/Home/QuickAddProblemSheet.swift` — no change needed (reused as-is by retro form)

**Interfaces:**
- Consumes: `QuickAddProblemSheet`, `SessionCompletion`, models, `PhotoStore`, `SessionDurationFormat`.
- Produces: `RetroSessionForm` (date + start time + duration pickers, gym/partner selection, add problems inline, save → writes HealthKit best-effort). `SessionDetailView(sessionID: PersistentIdentifier)` — full session readout with photo thumbnails, delete session action (cascades attempts, deletes photos + workout).

- [ ] **Step 1: Implement RetroSessionForm**

```swift
import SwiftUI
import SwiftData

struct RetroSessionForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Gym.name) private var gyms: [Gym]
    @Query(sort: \Partner.name) private var allPartners: [Partner]
    @Query(sort: \Session.startTime) private var allSessions: [Session]
    @Query private var unlockedAchievements: [Achievement]

    @State private var sessionDate = Date.now
    @State private var durationMinutes = 90
    @State private var selectedGym: Gym?
    @State private var selectedPartnerIDs: Set<PersistentIdentifier> = []
    @State private var pendingSession: Session?

    private let completion = SessionCompletion(workoutWriter: HealthKitWorkoutWriter())
    private static let durationChoices = [30, 45, 60, 75, 90, 105, 120, 150, 180, 240]

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date & start", selection: $sessionDate)
                Picker("Duration", selection: $durationMinutes) {
                    ForEach(Self.durationChoices, id: \.self) { minutes in
                        Text("\(minutes) min").tag(minutes)
                    }
                }
                Picker("Gym", selection: $selectedGym) {
                    ForEach(gyms) { gym in
                        Text(gym.name).tag(Optional(gym))
                    }
                }
                partnersSection
                problemsSection
            }
            .navigationTitle("Past Session")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: saveSession)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancelEntry)
                }
            }
            .onAppear(perform: prepareSession)
        }
    }

    private var partnersSection: some View {
        Section("Partners") {
            ForEach(allPartners) { partner in
                Toggle(partner.name, isOn: Binding(
                    get: { selectedPartnerIDs.contains(partner.persistentModelID) },
                    set: { isSelected in
                        if isSelected {
                            selectedPartnerIDs.insert(partner.persistentModelID)
                        } else {
                            selectedPartnerIDs.remove(partner.persistentModelID)
                        }
                    }
                ))
            }
        }
    }

    private var problemsSection: some View {
        Section("Problems") {
            if let pendingSession {
                ForEach(pendingSession.attempts) { attempt in
                    HStack {
                        Circle().fill(attempt.colorGrade.displayColor)
                            .frame(width: 16, height: 16)
                        Text(attempt.result.displayName)
                        Spacer()
                        Text("\(attempt.attemptCount)×").foregroundStyle(.secondary)
                    }
                }
                NavigationLink("Add problem") {
                    QuickAddProblemSheet(session: pendingSession)
                }
            }
        }
    }

    private func prepareSession() {
        guard pendingSession == nil else { return }
        let gym = gyms.first { $0.isDefault } ?? gyms.first
        selectedGym = gym
        let session = Session(startTime: sessionDate, gym: gym, partners: [])
        modelContext.insert(session)
        pendingSession = session
    }

    private func saveSession() {
        guard let session = pendingSession else { return }
        session.startTime = sessionDate
        session.date = sessionDate
        session.gym = selectedGym
        session.partners = allPartners.filter { selectedPartnerIDs.contains($0.persistentModelID) }
        let end = sessionDate.addingTimeInterval(TimeInterval(durationMinutes * 60))
        Task {
            let unlockedIDs = Set(unlockedAchievements.map(\.achievementID))
            let outcome = await completion.finish(
                session, endTime: end, allSessions: allSessions, unlockedIDs: unlockedIDs
            )
            for achievement in outcome.newAchievements {
                modelContext.insert(Achievement(achievementID: achievement.id))
            }
            try? modelContext.save()
            dismiss()
        }
    }

    private func cancelEntry() {
        if let pendingSession {
            modelContext.delete(pendingSession)
        }
        dismiss()
    }
}
```

- [ ] **Step 2: Implement SessionDetailView**

```swift
import SwiftUI
import SwiftData

struct SessionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let sessionID: PersistentIdentifier

    @State private var showingDeleteConfirmation = false
    private let photoStore = PhotoStore.makeDefault()
    private let completion = SessionCompletion(workoutWriter: HealthKitWorkoutWriter())

    private var session: Session? {
        modelContext.model(for: sessionID) as? Session
    }

    var body: some View {
        if let session {
            List {
                sessionInfoSection(session)
                attemptsSection(session)
            }
            .navigationTitle(session.startTime.formatted(date: .abbreviated, time: .omitted))
            .toolbar {
                Button("Delete", systemImage: "trash", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            }
            .confirmationDialog(
                "Delete this session?", isPresented: $showingDeleteConfirmation
            ) {
                Button("Delete Session", role: .destructive) { deleteSession(session) }
            }
        } else {
            ContentUnavailableView("Session not found", systemImage: "questionmark.circle")
        }
    }

    private func sessionInfoSection(_ session: Session) -> some View {
        Section {
            LabeledContent("Gym", value: session.gym?.name ?? "Unknown")
            LabeledContent("Duration", value: SessionDurationFormat.string(from: session.duration))
            if !session.partners.isEmpty {
                LabeledContent(
                    "Partners",
                    value: session.partners.map(\.name).joined(separator: ", ")
                )
            }
        }
    }

    private func attemptsSection(_ session: Session) -> some View {
        Section("Problems") {
            ForEach(session.attempts) { attempt in
                AttemptRow(attempt: attempt, photoStore: photoStore)
            }
        }
    }

    private func deleteSession(_ session: Session) {
        for attempt in session.attempts {
            if let filename = attempt.photoFilename {
                try? photoStore.deletePhoto(named: filename)
            }
        }
        Task {
            await completion.deleteWorkoutIfPresent(for: session)
            modelContext.delete(session)
            try? modelContext.save()
            dismiss()
        }
    }
}

struct AttemptRow: View {
    let attempt: ProblemAttempt
    let photoStore: PhotoStore

    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(attempt.colorGrade.displayColor).frame(width: 20, height: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(attempt.colorGrade.displayName) · \(attempt.result.displayName)")
                    .font(.subheadline.bold())
                if !attempt.styles.isEmpty {
                    Text(attempt.styles.map(\.displayName).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("\(attempt.attemptCount)×").monospacedDigit()
            photoThumbnail
        }
    }

    @ViewBuilder
    private var photoThumbnail: some View {
        if let filename = attempt.photoFilename,
           let imageData = photoStore.loadPhoto(named: filename),
           let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(.rect(cornerRadius: 8))
        }
    }
}
```

- [ ] **Step 3: Delete PendingScreens.swift, regenerate, run tests, build**

- [ ] **Step 4: Manual verify**

Add past session with problems → appears in recent list → open detail → delete works (attempts + photos gone).

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add retro session form and session detail with delete"
```

---

### Task 12: Calendar tab

**Files:**
- Create: `BoulderTracker/Calendar/CalendarView.swift`
- Create: `BoulderTracker/Calendar/MonthGrid.swift`
- Create: `BoulderTracker/Calendar/CalendarMonth.swift`
- Modify: `BoulderTracker/App/RootTabView.swift` (calendar placeholder → `CalendarView()`)
- Test: `BoulderTrackerTests/CalendarMonthTests.swift`

**Interfaces:**
- Consumes: models, `ColorGrade.displayColor`, `SessionDetailView`.
- Produces:
  - `struct CalendarMonth` (pure logic, testable) — `init(containing date: Date, calendar: Calendar)`, `var weeks: [[Date?]]` (nil = padding cell), `var monthTitle: String`, `func previous() -> CalendarMonth`, `func next() -> CalendarMonth`.
  - `CalendarView` — month navigation, dot per session day colored by hardest sent grade, tap day → session list → detail.

- [ ] **Step 1: Write failing tests** `BoulderTrackerTests/CalendarMonthTests.swift`

```swift
import Testing
import Foundation
@testable import BoulderTracker

struct CalendarMonthTests {
    private let calendar = Calendar(identifier: .iso8601)

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func weeksCoverWholeMonth() {
        let month = CalendarMonth(containing: makeDate(2026, 8, 15), calendar: calendar)
        let dayCells = month.weeks.flatMap { $0 }.compactMap { $0 }
        #expect(dayCells.count == 31)
        #expect(month.weeks.allSatisfy { $0.count == 7 })
    }

    @Test func previousAndNextNavigateMonths() {
        let august = CalendarMonth(containing: makeDate(2026, 8, 15), calendar: calendar)
        #expect(august.previous().monthTitle.contains("July"))
        #expect(august.next().monthTitle.contains("September"))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement CalendarMonth** `BoulderTracker/Calendar/CalendarMonth.swift`

```swift
import Foundation

struct CalendarMonth {
    let firstDay: Date
    private let calendar: Calendar

    init(containing date: Date, calendar: Calendar) {
        self.calendar = calendar
        let components = calendar.dateComponents([.year, .month], from: date)
        self.firstDay = calendar.date(from: components) ?? date
    }

    var monthTitle: String {
        firstDay.formatted(.dateTime.month(.wide).year())
    }

    var weeks: [[Date?]] {
        guard let dayRange = calendar.range(of: .day, in: .month, for: firstDay) else {
            return []
        }
        let leadingPadding = leadingEmptyCellCount
        var cells = [Date?](repeating: nil, count: leadingPadding)
        for dayNumber in dayRange {
            cells.append(calendar.date(
                byAdding: .day, value: dayNumber - 1, to: firstDay
            ))
        }
        let weekLength = 7
        while cells.count % weekLength != 0 { cells.append(nil) }
        return stride(from: 0, to: cells.count, by: weekLength).map {
            Array(cells[$0..<$0 + weekLength])
        }
    }

    func previous() -> CalendarMonth {
        offsetMonth(by: -1)
    }

    func next() -> CalendarMonth {
        offsetMonth(by: 1)
    }

    private var leadingEmptyCellCount: Int {
        let weekday = calendar.component(.weekday, from: firstDay)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private func offsetMonth(by monthDelta: Int) -> CalendarMonth {
        let shifted = calendar.date(byAdding: .month, value: monthDelta, to: firstDay) ?? firstDay
        return CalendarMonth(containing: shifted, calendar: calendar)
    }
}
```

- [ ] **Step 4: Run tests, verify pass**

- [ ] **Step 5: Implement MonthGrid + CalendarView**

`BoulderTracker/Calendar/MonthGrid.swift`:

```swift
import SwiftUI

struct MonthGrid: View {
    let month: CalendarMonth
    let sessionsByDay: [Date: [Session]]
    let onSelectDay: (Date) -> Void
    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(month.weeks.enumerated()), id: \.offset) { _, week in
                weekRow(week)
            }
        }
    }

    private func weekRow(_ week: [Date?]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                dayCell(day)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ day: Date?) -> some View {
        if let day {
            let daySessions = sessionsByDay[calendar.startOfDay(for: day)] ?? []
            VStack(spacing: 4) {
                Text(day, format: .dateTime.day())
                    .font(.callout)
                dayDot(for: daySessions)
            }
            .contentShape(.rect)
            .onTapGesture {
                if !daySessions.isEmpty { onSelectDay(day) }
            }
        } else {
            Color.clear.frame(height: 36)
        }
    }

    @ViewBuilder
    private func dayDot(for daySessions: [Session]) -> some View {
        if let hardest = StatsAggregator.hardestSend(of: daySessions) {
            Circle().fill(hardest.colorGrade.displayColor).frame(width: 8, height: 8)
        } else if !daySessions.isEmpty {
            Circle().fill(.secondary).frame(width: 8, height: 8)
        } else {
            Circle().fill(.clear).frame(width: 8, height: 8)
        }
    }
}
```

`BoulderTracker/Calendar/CalendarView.swift`:

```swift
import SwiftUI
import SwiftData

struct CalendarView: View {
    @Query(sort: \Session.startTime, order: .reverse) private var sessions: [Session]
    @State private var displayedMonth = CalendarMonth(containing: .now, calendar: .current)
    @State private var selectedDaySessions: [Session] = []
    @State private var showingDaySheet = false
    private let calendar = Calendar.current

    private var sessionsByDay: [Date: [Session]] {
        Dictionary(grouping: sessions.filter { !$0.isLive }) {
            calendar.startOfDay(for: $0.startTime)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                monthHeader
                MonthGrid(
                    month: displayedMonth,
                    sessionsByDay: sessionsByDay,
                    onSelectDay: presentDay
                )
                Spacer()
            }
            .padding()
            .navigationTitle("Calendar")
            .sheet(isPresented: $showingDaySheet) { daySheet }
        }
    }

    private var monthHeader: some View {
        HStack {
            Button("Previous month", systemImage: "chevron.left") {
                displayedMonth = displayedMonth.previous()
            }
            .labelStyle(.iconOnly)
            Spacer()
            Text(displayedMonth.monthTitle).font(.headline)
            Spacer()
            Button("Next month", systemImage: "chevron.right") {
                displayedMonth = displayedMonth.next()
            }
            .labelStyle(.iconOnly)
        }
        .buttonStyle(.glass)
    }

    private var daySheet: some View {
        NavigationStack {
            List(selectedDaySessions) { session in
                NavigationLink {
                    SessionDetailView(sessionID: session.persistentModelID)
                } label: {
                    SessionRow(session: session)
                }
            }
            .navigationTitle("Sessions")
        }
        .presentationDetents([.medium, .large])
    }

    private func presentDay(_ day: Date) {
        selectedDaySessions = sessionsByDay[calendar.startOfDay(for: day)] ?? []
        showingDaySheet = true
    }
}
```

Wire into RootTabView calendar tab.

- [ ] **Step 6: Regenerate, run full suite, build, manual verify**

Calendar shows dots on session days, dot color = hardest send, tap opens day sheet → detail.

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "feat: add calendar tab with month grid and session dots"
```

---

### Task 13: Stats tab

**Files:**
- Create: `BoulderTracker/Stats/StatsView.swift`
- Create: `BoulderTracker/Stats/GradeProgressionChart.swift`
- Create: `BoulderTracker/Stats/GradeDistributionChart.swift`
- Create: `BoulderTracker/Stats/StyleBreakdownChart.swift`
- Create: `BoulderTracker/Stats/WeeklyVolumeChart.swift`
- Create: `BoulderTracker/Stats/PersonalBestsSection.swift`
- Modify: `BoulderTracker/App/RootTabView.swift` (stats placeholder → `StatsView()`)

**Interfaces:**
- Consumes: `StatsAggregator`, `StatsPeriod`, `StatsSummary`, models, `ColorGrade.displayColor`, `SessionDurationFormat`, `MetricTile` (Task 9).
- Produces: `StatsView` with period picker + charts. Chart data structs: `GradeSendPoint { weekStart: Date, grade: ColorGrade, sendCount: Int }`, `StyleRatePoint { style: RouteStyle, rate: Double }`, `WeeklyVolumePoint { weekStart: Date, problemCount: Int }` — computed inline in each chart view from `[Session]`.

- [ ] **Step 1: Implement StatsView**

```swift
import SwiftUI
import SwiftData

struct StatsView: View {
    @Query(sort: \Session.startTime) private var allSessions: [Session]
    @State private var period: StatsPeriod = .threeMonths

    private var periodSessions: [Session] {
        let finished = allSessions.filter { !$0.isLive }
        let interval = period.interval(endingAt: .now, calendar: .current)
        return StatsAggregator.sessions(finished, in: interval)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    periodPicker
                    summaryCards
                    GradeProgressionChart(sessions: periodSessions)
                    GradeDistributionChart(sessions: periodSessions)
                    StyleBreakdownChart(sessions: periodSessions)
                    WeeklyVolumeChart(sessions: periodSessions)
                    PersonalBestsSection(sessions: allSessions.filter { !$0.isLive })
                }
                .padding()
            }
            .navigationTitle("Stats")
        }
    }

    private var periodPicker: some View {
        Picker("Period", selection: $period) {
            ForEach(StatsPeriod.allCases) { statsPeriod in
                Text(statsPeriod.displayName).tag(statsPeriod)
            }
        }
        .pickerStyle(.segmented)
    }

    private var summaryCards: some View {
        let summary = StatsAggregator.summary(of: periodSessions)
        return VStack(spacing: 12) {
            HStack {
                MetricTile(label: "Sessions", valueText: "\(summary.sessionCount)")
                MetricTile(
                    label: "Time",
                    valueText: SessionDurationFormat.string(from: summary.totalDuration)
                )
            }
            HStack {
                MetricTile(label: "Problems", valueText: "\(summary.problemCount)")
                MetricTile(label: "Sends", valueText: "\(summary.sendCount)")
                MetricTile(
                    label: "Flash rate",
                    valueText: summary.flashRate.formatted(.percent.precision(.fractionLength(0)))
                )
            }
        }
    }
}
```

- [ ] **Step 2: Implement the four charts**

`BoulderTracker/Stats/GradeProgressionChart.swift`:

```swift
import SwiftUI
import Charts

struct GradeSendPoint: Identifiable {
    let weekStart: Date
    let grade: ColorGrade
    let sendCount: Int
    var id: String { "\(weekStart.timeIntervalSince1970)-\(grade.rawValue)" }
}

struct GradeProgressionChart: View {
    let sessions: [Session]
    private let calendar = Calendar.current

    private var points: [GradeSendPoint] {
        var counts: [Date: [ColorGrade: Int]] = [:]
        for session in sessions {
            guard let week = calendar.dateInterval(of: .weekOfYear, for: session.startTime)?.start
            else { continue }
            for attempt in session.attempts where attempt.result.countsAsSend {
                counts[week, default: [:]][attempt.colorGrade, default: 0] += 1
            }
        }
        return counts.flatMap { week, grades in
            grades.map { GradeSendPoint(weekStart: week, grade: $0.key, sendCount: $0.value) }
        }
    }

    var body: some View {
        ChartCard(title: "Sends per grade over time") {
            Chart(points) { point in
                BarMark(
                    x: .value("Week", point.weekStart, unit: .weekOfYear),
                    y: .value("Sends", point.sendCount)
                )
                .foregroundStyle(point.grade.displayColor)
            }
            .frame(height: 200)
        }
    }
}

struct ChartCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .glassEffect(in: .rect(cornerRadius: 20))
    }
}
```

`BoulderTracker/Stats/GradeDistributionChart.swift`:

```swift
import SwiftUI
import Charts

struct GradeDistributionChart: View {
    let sessions: [Session]

    private var counts: [(grade: ColorGrade, sendCount: Int)] {
        let perGrade = StatsAggregator.sendCountPerGrade(of: sessions)
        return ColorGrade.allCases.compactMap { grade in
            guard let sendCount = perGrade[grade] else { return nil }
            return (grade, sendCount)
        }
    }

    var body: some View {
        ChartCard(title: "Grade distribution") {
            Chart(counts, id: \.grade) { entry in
                BarMark(
                    x: .value("Grade", entry.grade.displayName),
                    y: .value("Sends", entry.sendCount)
                )
                .foregroundStyle(entry.grade.displayColor)
            }
            .frame(height: 180)
        }
    }
}
```

`BoulderTracker/Stats/StyleBreakdownChart.swift`:

```swift
import SwiftUI
import Charts

struct StyleBreakdownChart: View {
    let sessions: [Session]

    private var rates: [(style: RouteStyle, rate: Double)] {
        StatsAggregator.sendRatePerStyle(of: sessions)
            .map { (style: $0.key, rate: $0.value) }
            .sorted { $0.rate > $1.rate }
    }

    var body: some View {
        if !rates.isEmpty {
            ChartCard(title: "Send rate by style") {
                Chart(rates, id: \.style) { entry in
                    BarMark(
                        x: .value("Send rate", entry.rate),
                        y: .value("Style", entry.style.displayName)
                    )
                    .foregroundStyle(.green.gradient)
                }
                .chartXScale(domain: 0...1)
                .frame(height: CGFloat(rates.count) * 28 + 40)
            }
        }
    }
}
```

`BoulderTracker/Stats/WeeklyVolumeChart.swift`:

```swift
import SwiftUI
import Charts

struct WeeklyVolumePoint: Identifiable {
    let weekStart: Date
    let problemCount: Int
    var id: Date { weekStart }
}

struct WeeklyVolumeChart: View {
    let sessions: [Session]
    private let calendar = Calendar.current

    private var points: [WeeklyVolumePoint] {
        let byWeek = Dictionary(grouping: sessions) { session in
            calendar.dateInterval(of: .weekOfYear, for: session.startTime)?.start ?? .distantPast
        }
        return byWeek
            .map { WeeklyVolumePoint(weekStart: $0.key, problemCount: $0.value.flatMap(\.attempts).count) }
            .sorted { $0.weekStart < $1.weekStart }
    }

    var body: some View {
        ChartCard(title: "Weekly volume") {
            Chart(points) { point in
                LineMark(
                    x: .value("Week", point.weekStart, unit: .weekOfYear),
                    y: .value("Problems", point.problemCount)
                )
                .interpolationMethod(.catmullRom)
                PointMark(
                    x: .value("Week", point.weekStart, unit: .weekOfYear),
                    y: .value("Problems", point.problemCount)
                )
            }
            .frame(height: 160)
        }
    }
}
```

- [ ] **Step 3: Implement PersonalBestsSection**

```swift
import SwiftUI

struct PersonalBestsSection: View {
    let sessions: [Session]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Personal bests").font(.headline)
            bestRow(label: "Hardest flash", attempt: StatsAggregator.hardestFlash(of: sessions))
            bestRow(label: "Hardest send", attempt: StatsAggregator.hardestSend(of: sessions))
            streakRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .glassEffect(in: .rect(cornerRadius: 20))
    }

    @ViewBuilder
    private func bestRow(label: String, attempt: ProblemAttempt?) -> some View {
        HStack {
            Text(label)
            Spacer()
            if let attempt {
                Circle().fill(attempt.colorGrade.displayColor).frame(width: 14, height: 14)
                Text(attempt.colorGrade.displayName).bold()
            } else {
                Text("—").foregroundStyle(.secondary)
            }
        }
    }

    private var streakRow: some View {
        HStack {
            Text("Weekly streak")
            Spacer()
            let streak = StatsAggregator.weeklyStreak(
                of: sessions, calendar: .current, referenceDate: .now
            )
            Text("\(streak) week\(streak == 1 ? "" : "s")").bold()
        }
    }
}
```

- [ ] **Step 4: Wire into RootTabView, regenerate, run suite, build, manual verify**

Log a few varied sessions in simulator; all four charts render, period picker filters.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add stats tab with charts and personal bests"
```

---

### Task 14: Roadmap tab

**Files:**
- Create: `BoulderTracker/Roadmap/RoadmapContent.swift` (static data — full user-provided content)
- Create: `BoulderTracker/Roadmap/RoadmapView.swift`
- Create: `BoulderTracker/Roadmap/RoadmapLevelSection.swift`
- Modify: `BoulderTracker/App/RootTabView.swift` (roadmap placeholder → `RoadmapView()`)
- Test: `BoulderTrackerTests/RoadmapContentTests.swift`

**Interfaces:**
- Consumes: `ColorGrade`, `RoadmapProgress` model.
- Produces:
  - `struct RoadmapItem: Identifiable` — `let id: String` (stable, format `"<grade>-<category>-<index>"`), `let text: String`.
  - `struct RoadmapItemGroup: Identifiable` — `let id: String`, `let heading: String` ("Focus"/"Learn"/"Training"/"Milestones"), `let items: [RoadmapItem]`.
  - `struct RoadmapLevel: Identifiable` — `let id: String`, `let grade: ColorGrade`, `let title: String`, `let goal: String`, `let groups: [RoadmapItemGroup]`; `var allItems: [RoadmapItem]`.
  - `enum RoadmapContent { static let levels: [RoadmapLevel] }` — all six levels verbatim from spec §5 Tab 4 / user content.
  - `RoadmapView` — sections with checkboxes bound to `RoadmapProgress` rows, progress ring per level, current-level highlight.

- [ ] **Step 1: Write failing tests** `BoulderTrackerTests/RoadmapContentTests.swift`

```swift
import Testing
@testable import BoulderTracker

struct RoadmapContentTests {
    @Test func sixLevelsInGradeOrder() {
        let grades = RoadmapContent.levels.map(\.grade)
        #expect(grades == ColorGrade.allCases)
    }

    @Test func allItemIDsAreUnique() {
        let ids = RoadmapContent.levels.flatMap(\.allItems).map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func everyLevelHasGoalAndItems() {
        for level in RoadmapContent.levels {
            #expect(!level.goal.isEmpty)
            #expect(!level.allItems.isEmpty)
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement RoadmapContent** `BoulderTracker/Roadmap/RoadmapContent.swift`

Structure (content below is the complete, exact copy to ship — build each level with the `makeGroup` helper):

```swift
import Foundation

struct RoadmapItem: Identifiable {
    let id: String
    let text: String
}

struct RoadmapItemGroup: Identifiable {
    let id: String
    let heading: String
    let items: [RoadmapItem]
}

struct RoadmapLevel: Identifiable {
    let id: String
    let grade: ColorGrade
    let title: String
    let goal: String
    let groups: [RoadmapItemGroup]

    var allItems: [RoadmapItem] { groups.flatMap(\.items) }
}

enum RoadmapContent {
    static let levels: [RoadmapLevel] = [
        greenLevel, blueLevel, redLevel, blackLevel, whiteLevel, yellowLevel,
    ]

    private static func makeGroup(grade: ColorGrade, heading: String,
                                  items: [String]) -> RoadmapItemGroup {
        let gradeKey = grade.displayName.lowercased()
        let headingKey = heading.lowercased()
        return RoadmapItemGroup(
            id: "\(gradeKey)-\(headingKey)",
            heading: heading,
            items: items.enumerated().map { index, text in
                RoadmapItem(id: "\(gradeKey)-\(headingKey)-\(index)", text: text)
            }
        )
    }

    private static var greenLevel: RoadmapLevel {
        RoadmapLevel(
            id: "green", grade: .green, title: "Learn to Climb",
            goal: "Complete most green problems.",
            groups: [
                makeGroup(grade: .green, heading: "Focus", items: [
                    "Footwork", "Balance", "Straight arms",
                    "Trust your feet", "Learn to fall safely",
                ]),
                makeGroup(grade: .green, heading: "Milestones", items: [
                    "Flash nearly all green problems.",
                    "Climb for 60–90 minutes without getting overly pumped.",
                ]),
            ]
        )
    }

    private static var blueLevel: RoadmapLevel {
        RoadmapLevel(
            id: "blue", grade: .blue, title: "Build Technique",
            goal: "Become a confident climber.",
            groups: [
                makeGroup(grade: .blue, heading: "Learn", items: [
                    "Flagging", "Drop knees", "Smearing", "Rock-overs",
                    "Basic dynamic movement",
                ]),
                makeGroup(grade: .blue, heading: "Training", items: [
                    "Climb 2–3 times/week.",
                    "Start core and pull-up training.",
                ]),
                makeGroup(grade: .blue, heading: "Milestones", items: [
                    "Flash many blues.",
                    "Finish most blues within a few attempts.",
                    "Start projecting harder blues.",
                ]),
            ]
        )
    }

    private static var redLevel: RoadmapLevel {
        RoadmapLevel(
            id: "red", grade: .red, title: "Intermediate Climber",
            goal: "Climb with intention rather than brute force.",
            groups: [
                makeGroup(grade: .red, heading: "Learn", items: [
                    "Heel hooks", "Toe hooks", "Body tension",
                    "Route reading", "Efficient resting",
                ]),
                makeGroup(grade: .red, heading: "Training", items: [
                    "3 climbing sessions/week.",
                    "1–2 strength sessions.",
                    "Begin light finger training (only if you've climbed consistently for ~6–12 months and your fingers tolerate the load).",
                ]),
                makeGroup(grade: .red, heading: "Milestones", items: [
                    "Send red projects over several sessions.",
                    "Identify whether failures are due to technique, strength, or beta.",
                ]),
            ]
        )
    }

    private static var blackLevel: RoadmapLevel {
        RoadmapLevel(
            id: "black", grade: .black, title: "Advanced",
            goal: "Develop high-level strength and movement.",
            groups: [
                makeGroup(grade: .black, heading: "Focus", items: [
                    "Limit bouldering", "Powerful moves", "Compression",
                    "Coordination", "Finger strength", "Project tactics",
                ]),
                makeGroup(grade: .black, heading: "Training", items: [
                    "Structured cycles: strength", "Structured cycles: power",
                    "Structured cycles: performance", "Structured cycles: deload",
                ]),
                makeGroup(grade: .black, heading: "Milestones", items: [
                    "Complete black projects after dedicated effort.",
                    "Adapt your beta to different styles.",
                ]),
            ]
        )
    }

    private static var whiteLevel: RoadmapLevel {
        RoadmapLevel(
            id: "white", grade: .white, title: "Very Advanced",
            goal: "Refine every aspect of climbing.",
            groups: [
                makeGroup(grade: .white, heading: "Focus", items: [
                    "Efficient projecting", "Recovery", "Advanced finger training",
                    "Video analysis", "Outdoor performance (if interested)",
                ]),
            ]
        )
    }

    private static var yellowLevel: RoadmapLevel {
        RoadmapLevel(
            id: "yellow", grade: .yellow, title: "Elite",
            goal: "Highly individualized training.",
            groups: [
                makeGroup(grade: .yellow, heading: "Focus", items: [
                    "Limit strength", "Advanced board climbing",
                    "Detailed training plans", "Nutrition and recovery optimization",
                    "Long-term project planning",
                ]),
            ]
        )
    }
}
```

- [ ] **Step 4: Run tests, verify pass**

- [ ] **Step 5: Implement RoadmapLevelSection + RoadmapView**

`BoulderTracker/Roadmap/RoadmapLevelSection.swift`:

```swift
import SwiftUI
import SwiftData

struct RoadmapLevelSection: View {
    @Environment(\.modelContext) private var modelContext
    let level: RoadmapLevel
    let checkedItemIDs: Set<String>
    let isCurrentLevel: Bool

    private var progress: Double {
        let total = level.allItems.count
        guard total > 0 else { return 0 }
        let checked = level.allItems.filter { checkedItemIDs.contains($0.id) }.count
        return Double(checked) / Double(total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Text(level.goal).font(.subheadline).foregroundStyle(.secondary)
            ForEach(level.groups) { group in
                groupView(group)
            }
        }
        .padding()
        .glassEffect(in: .rect(cornerRadius: 20))
        .overlay {
            if isCurrentLevel {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(level.grade.displayColor, lineWidth: 2)
            }
        }
    }

    private var header: some View {
        HStack {
            Circle().fill(level.grade.displayColor).frame(width: 24, height: 24)
            Text(level.title).font(.title3.bold())
            Spacer()
            ProgressView(value: progress)
                .progressViewStyle(.circular)
                .tint(level.grade.displayColor)
        }
    }

    private func groupView(_ group: RoadmapItemGroup) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(group.heading).font(.caption.bold()).foregroundStyle(.secondary)
            ForEach(group.items) { item in
                checkRow(item)
            }
        }
    }

    private func checkRow(_ item: RoadmapItem) -> some View {
        let isChecked = checkedItemIDs.contains(item.id)
        return Button {
            toggleItem(item, currentlyChecked: isChecked)
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isChecked ? level.grade.displayColor : .secondary)
                Text(item.text)
                    .strikethrough(isChecked)
                    .foregroundStyle(isChecked ? .secondary : .primary)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    private func toggleItem(_ item: RoadmapItem, currentlyChecked: Bool) {
        if currentlyChecked {
            let itemID = item.id
            try? modelContext.delete(
                model: RoadmapProgress.self,
                where: #Predicate { $0.itemID == itemID }
            )
        } else {
            modelContext.insert(RoadmapProgress(itemID: item.id))
        }
        try? modelContext.save()
    }
}
```

`BoulderTracker/Roadmap/RoadmapView.swift`:

```swift
import SwiftUI
import SwiftData

struct RoadmapView: View {
    @Query private var progressRows: [RoadmapProgress]

    private var checkedItemIDs: Set<String> { Set(progressRows.map(\.itemID)) }

    private var currentLevelID: String? {
        RoadmapContent.levels.first { level in
            level.allItems.contains { !checkedItemIDs.contains($0.id) }
        }?.id
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(RoadmapContent.levels) { level in
                        RoadmapLevelSection(
                            level: level,
                            checkedItemIDs: checkedItemIDs,
                            isCurrentLevel: level.id == currentLevelID
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Roadmap")
        }
    }
}
```

Wire into RootTabView roadmap tab.

- [ ] **Step 6: Regenerate, run suite, build, manual verify**

Checkboxes persist across relaunch; current level ring highlights first incomplete level.

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "feat: add roadmap tab with manual progress tracking"
```

---

### Task 15: Profile tab

**Files:**
- Create: `BoulderTracker/Profile/ProfileView.swift`
- Create: `BoulderTracker/Profile/AchievementsGrid.swift`
- Create: `BoulderTracker/Profile/GymListView.swift`
- Create: `BoulderTracker/Profile/PartnerListView.swift`
- Create: `BoulderTracker/Profile/SessionExport.swift`
- Modify: `BoulderTracker/App/RootTabView.swift` (profile placeholder → `ProfileView()`)
- Test: `BoulderTrackerTests/SessionExportTests.swift`

**Interfaces:**
- Consumes: models, `AchievementEngine.definitions`, `HealthKitWorkoutWriter`.
- Produces:
  - `enum SessionExport { static func jsonData(from sessions: [Session]) throws -> Data }` — Codable DTOs (`ExportedSession`, `ExportedAttempt`) with ISO8601 dates.
  - `ProfileView` with achievements grid, gym/partner lists, HealthKit authorization button, ShareLink export.

- [ ] **Step 1: Write failing test** `BoulderTrackerTests/SessionExportTests.swift`

```swift
import Testing
import Foundation
@testable import BoulderTracker

@MainActor
struct SessionExportTests {
    @Test func exportContainsSessionsAndAttempts() throws {
        let gym = Gym(name: "Klättervigören Jönköping")
        let session = Session(startTime: .now, gym: gym, partners: [Partner(name: "Alex")])
        session.endTime = .now.addingTimeInterval(3600)
        session.attempts.append(ProblemAttempt(
            colorGrade: .red, styles: [.crimp], attemptCount: 2, result: .send
        ))

        let jsonData = try SessionExport.jsonData(from: [session])
        let decoded = try JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]]

        #expect(decoded?.count == 1)
        #expect(decoded?.first?["gym"] as? String == "Klättervigören Jönköping")
        let attempts = decoded?.first?["attempts"] as? [[String: Any]]
        #expect(attempts?.first?["colorGrade"] as? String == "red")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Implement SessionExport** `BoulderTracker/Profile/SessionExport.swift`

```swift
import Foundation

struct ExportedAttempt: Codable {
    let colorGrade: String
    let styles: [String]
    let attemptCount: Int
    let result: String
    let notes: String?
}

struct ExportedSession: Codable {
    let startTime: Date
    let endTime: Date?
    let gym: String?
    let partners: [String]
    let notes: String?
    let attempts: [ExportedAttempt]
}

enum SessionExport {
    static func jsonData(from sessions: [Session]) throws -> Data {
        let exported = sessions.map { session in
            ExportedSession(
                startTime: session.startTime,
                endTime: session.endTime,
                gym: session.gym?.name,
                partners: session.partners.map(\.name),
                notes: session.notes,
                attempts: session.attempts.map { attempt in
                    ExportedAttempt(
                        colorGrade: gradeKey(for: attempt.colorGrade),
                        styles: attempt.styles.map(\.rawValue),
                        attemptCount: attempt.attemptCount,
                        result: attempt.result.rawValue,
                        notes: attempt.notes
                    )
                }
            )
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(exported)
    }

    private static func gradeKey(for grade: ColorGrade) -> String {
        grade.displayName.lowercased()
    }
}
```

- [ ] **Step 4: Run test, verify pass**

- [ ] **Step 5: Implement AchievementsGrid**

```swift
import SwiftUI
import SwiftData

struct AchievementsGrid: View {
    @Query private var unlocked: [Achievement]
    private let columns = [GridItem(.adaptive(minimum: 100))]

    private var unlockedByID: [String: Achievement] {
        Dictionary(uniqueKeysWithValues: unlocked.map { ($0.achievementID, $0) })
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(AchievementEngine.definitions) { definition in
                achievementTile(definition)
            }
        }
    }

    private func achievementTile(_ definition: AchievementDefinition) -> some View {
        let unlockedRow = unlockedByID[definition.id]
        return VStack(spacing: 6) {
            Image(systemName: definition.symbolName)
                .font(.title2)
                .foregroundStyle(unlockedRow == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(.yellow))
            Text(definition.title)
                .font(.caption.bold())
                .multilineTextAlignment(.center)
            if let unlockedRow {
                Text(unlockedRow.unlockedAt, format: .dateTime.day().month().year())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text(definition.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding(8)
        .glassEffect(in: .rect(cornerRadius: 14))
        .opacity(unlockedRow == nil ? 0.5 : 1)
    }
}
```

- [ ] **Step 6: Implement GymListView + PartnerListView**

`BoulderTracker/Profile/GymListView.swift`:

```swift
import SwiftUI
import SwiftData

struct GymListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Gym.name) private var gyms: [Gym]
    @State private var newGymName = ""

    var body: some View {
        List {
            ForEach(gyms) { gym in
                HStack {
                    Text(gym.name)
                    if gym.isDefault {
                        Spacer()
                        Text("Default").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete(perform: deleteGyms)
            HStack {
                TextField("New gym name", text: $newGymName)
                Button("Add", action: addGym)
                    .disabled(newGymName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .navigationTitle("Gyms")
    }

    private func addGym() {
        let trimmedName = newGymName.trimmingCharacters(in: .whitespaces)
        modelContext.insert(Gym(name: trimmedName))
        newGymName = ""
        try? modelContext.save()
    }

    private func deleteGyms(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(gyms[index])
        }
        try? modelContext.save()
    }
}
```

`BoulderTracker/Profile/PartnerListView.swift` — identical shape for `Partner` (name field, add, delete; no isDefault column):

```swift
import SwiftUI
import SwiftData

struct PartnerListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Partner.name) private var partners: [Partner]
    @State private var newPartnerName = ""

    var body: some View {
        List {
            ForEach(partners) { partner in
                Text(partner.name)
            }
            .onDelete(perform: deletePartners)
            HStack {
                TextField("New partner name", text: $newPartnerName)
                Button("Add", action: addPartner)
                    .disabled(newPartnerName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .navigationTitle("Partners")
    }

    private func addPartner() {
        let trimmedName = newPartnerName.trimmingCharacters(in: .whitespaces)
        modelContext.insert(Partner(name: trimmedName))
        newPartnerName = ""
        try? modelContext.save()
    }

    private func deletePartners(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(partners[index])
        }
        try? modelContext.save()
    }
}
```

- [ ] **Step 7: Implement ProfileView**

```swift
import SwiftUI
import SwiftData

struct ProfileView: View {
    @Query(sort: \Session.startTime) private var sessions: [Session]
    @State private var exportedJSON: Data?
    private let workoutWriter = HealthKitWorkoutWriter()

    var body: some View {
        NavigationStack {
            List {
                Section("Achievements") {
                    AchievementsGrid()
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                Section("Manage") {
                    NavigationLink("Gyms") { GymListView() }
                    NavigationLink("Partners") { PartnerListView() }
                }
                Section("Apple Health") {
                    Button("Grant Health access") {
                        Task { try? await workoutWriter.requestAuthorization() }
                    }
                }
                Section("Data") {
                    exportLink
                }
            }
            .navigationTitle("Profile")
        }
    }

    @ViewBuilder
    private var exportLink: some View {
        let finished = sessions.filter { !$0.isLive }
        if let jsonData = try? SessionExport.jsonData(from: finished) {
            ShareLink(
                item: jsonData.base64EncodedString(),
                subject: Text("Boulder Tracker export"),
                preview: SharePreview("Sessions JSON")
            ) {
                Label("Export sessions as JSON", systemImage: "square.and.arrow.up")
            }
        }
    }
}
```

Note: for a nicer file share, write `jsonData` to a temp `.json` file URL and `ShareLink(item: fileURL)` — implement that variant if base64 sharing feels wrong during manual verify:

```swift
private func exportFileURL(from jsonData: Data) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("boulder-tracker-export.json")
    try jsonData.write(to: url, options: .atomic)
    return url
}
```

- [ ] **Step 8: Wire into RootTabView, regenerate, run suite, build, manual verify**

Achievements show first-session unlocked, gyms/partners CRUD works, health prompt appears, export shares JSON.

- [ ] **Step 9: Commit**

```bash
git add -A && git commit -m "feat: add profile tab with achievements, management, and export"
```

---

### Task 16: Resume-or-end prompt + final polish pass

**Files:**
- Modify: `BoulderTracker/Home/HomeView.swift` (stale live-session prompt)
- Modify: any view needing glass polish
- Create: `docs/manual-test-checklist.md`

**Interfaces:**
- Consumes: everything.
- Produces: shippable v1.

- [ ] **Step 1: Add stale live-session prompt to HomeView**

Spec §9: app killed mid-session → on relaunch offer resume or end. Add to `HomeView`:

```swift
@State private var showingStaleSessionPrompt = false
private static let staleSessionThreshold: TimeInterval = 6 * 3600
```

In `body`, on appear check: if `liveSession` exists and `Date.now.timeIntervalSince(liveSession.startTime) > Self.staleSessionThreshold`, set `showingStaleSessionPrompt = true`. Confirmation dialog:

```swift
.confirmationDialog(
    "Session still running from \(liveSession?.startTime.formatted(date: .abbreviated, time: .shortened) ?? "")",
    isPresented: $showingStaleSessionPrompt
) {
    Button("Keep climbing") {}
    Button("End it now") { endStaleSession() }
}
```

`endStaleSession()` calls the same `SessionCompletion.finish` path with `endTime = .now` (extract shared ending logic from `LiveSessionView.endSession` into a small `SessionEnder` helper in `BoulderTracker/Home/SessionEnder.swift` if duplication appears — two call sites justify it):

```swift
import Foundation
import SwiftData

@MainActor
struct SessionEnder {
    let modelContext: ModelContext
    let completion: SessionCompletion

    func endSession(_ session: Session, allSessions: [Session],
                    unlockedAchievements: [Achievement]) async -> SessionCompletionOutcome {
        let unlockedIDs = Set(unlockedAchievements.map(\.achievementID))
        let outcome = await completion.finish(
            session, endTime: .now, allSessions: allSessions, unlockedIDs: unlockedIDs
        )
        for achievement in outcome.newAchievements {
            modelContext.insert(Achievement(achievementID: achievement.id))
        }
        try? modelContext.save()
        return outcome
    }
}
```

Refactor `LiveSessionView.endSession` to use `SessionEnder` (behavior unchanged — commit separately per refactoring rule).

- [ ] **Step 2: Run full test suite + build**

All green.

- [ ] **Step 3: Write manual test checklist** `docs/manual-test-checklist.md`

```markdown
# Manual Test Checklist (run on device before calling v1 done)

- [ ] Fresh install: default gym seeded, all tabs render empty states
- [ ] Start live session → add problems of every grade → tally correct
- [ ] Photo from camera attaches and shows in detail
- [ ] Flash result locks attempt stepper at 1
- [ ] End session → summary correct → Health shows climbing workout
- [ ] Kill app mid-session → relaunch → live view restored
- [ ] Stale session (>6h) prompts resume-or-end
- [ ] Retro session with problems → calendar dot appears, correct color
- [ ] Delete session → attempts, photos, Health workout all gone
- [ ] Stats: all periods filter correctly, charts render
- [ ] Roadmap checks persist relaunch; current level ring correct
- [ ] Achievements unlock (first-session, first-flash, night-owl testable)
- [ ] JSON export opens/share correctly
- [ ] Dark mode + Liquid Glass looks right on all five tabs
```

- [ ] **Step 4: Run through checklist on simulator; device pass done by user**

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add stale session recovery and manual test checklist"
```

---

## Deferred (spec §12 — do not build)

Apple Watch app, Strava OAuth, shoe logging, route discontinuation, skill-net radar chart, iCloud sync, custom route styles. The skill net becomes a `StatsView` addition later; `sendRatePerStyle` already produces its data.
