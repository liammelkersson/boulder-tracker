# Project Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make a climbing project a stored, editable entity the user can add, rename, complete, archive, and delete, instead of a group derived from `SessionProblem` rows.

**Architecture:** A new SwiftData `Project` model owns identity and lifecycle; `SessionProblem` gains an optional `project` link and keeps owning attempt logs. A one-time backfill converts today's derived groups into stored rows, then `ProjectAggregator` is deleted and its readers (`ProjectsSheet`, `CurrentProjectCard`) query `Project` directly. Statistics move to a `ProjectStats` value type; the "which project is current" pointer moves from `@AppStorage` to `Project.isCurrent` behind a single writer.

**Tech Stack:** Swift 6, SwiftUI, SwiftData (CloudKit-backed), Swift Testing, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-09-01-project-management-design.md`

## Global Constraints

- **CloudKit schema rules:** every stored attribute carries a default value; every to-many relationship is optional and defaulted; every relationship declares an explicit `inverse`. A model that breaks these fails container creation at launch. See the comment at the top of `BoulderTracker/Models/Session.swift`.
- **New files need `xcodegen generate`.** `project.yml` globs sources by directory, so a new `.swift` file is invisible to the build until the project is regenerated. Run `xcodegen generate` after creating any file and before building.
- **iOS test command:** `xcodebuild test -project BoulderTracker.xcodeproj -scheme BoulderTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`. If that simulator is absent, run `xcrun simctl list devices available` and substitute the newest available iPhone everywhere in this plan.
- **Single-test runs** append `-only-testing:BoulderTrackerTests/<SuiteName>/<testName>`.
- **Saving:** views never call `try? modelContext.save()`; they call `modelContext.saveReportingFailure(operation: "<short description>")`.
- **Deleted rows:** anything iterating fetched models filters with `.persisted` before touching properties (see `BoulderTracker/Models/PersistentModelInvalidation.swift`).
- **User-facing string sorts** use `localizedStandardCompare`, never `<` or `compareTo`.
- **No TODO/FIXME markers, no commented-out code, no `Any`.** Function bodies stay under 30 lines.
- **Legacy attribute:** `SessionProblem.isProject` must NOT be deleted in this plan. Other devices still sync the old CloudKit schema; it is retired in a later release. After Task 9 nothing writes it and only `ProjectBackfill` reads it.

---

### Task 1: Project model and status enum

**Files:**
- Create: `BoulderTracker/Models/Project.swift`
- Create: `BoulderTracker/Models/ProjectStatus.swift`
- Modify: `BoulderTracker/Models/SessionProblem.swift` (add the `project` relationship)
- Modify: `BoulderTracker/App/BoulderTrackerApp.swift:29-32` (schema array)
- Test: `BoulderTrackerTests/ModelRoundTripTests.swift` (shared in-memory container + a new round-trip test)

**Interfaces:**
- Consumes: nothing.
- Produces: `Project` (`name: String`, `colorGrade: ColorGrade`, `status: ProjectStatus`, `notes: String?`, `createdDate: Date`, `isCurrent: Bool`, `isSampleData: Bool`, `gym: Gym?`, `problems: [SessionProblem]?`), `Project.init(name:colorGrade:gym:status:createdDate:)`, `Project.markSentIfActive()`, `ProjectStatus.active/.sent/.archived` with `displayName`, and `SessionProblem.project: Project?`.

- [ ] **Step 1: Write the failing test**

Append to `BoulderTrackerTests/ModelRoundTripTests.swift`:

```swift
@Test func projectRoundTripsWithLinkedProblem() throws {
    let container = try makeInMemoryContainer()
    let context = ModelContext(container)
    let gym = Gym(name: "Klätterverket")
    context.insert(gym)
    let session = Session(startTime: .now, gym: gym, partners: [])
    let problem = SessionProblem(name: "Elektra", colorGrade: .red, styles: [.crimp])
    session.problems = [problem]
    context.insert(session)
    let project = Project(name: "Elektra", colorGrade: .red, gym: gym)
    context.insert(project)
    problem.project = project
    try context.save()

    let stored = try context.fetch(FetchDescriptor<Project>())
    #expect(stored.count == 1)
    #expect(stored.first?.status == .active)
    #expect(stored.first?.isCurrent == false)
    #expect(stored.first?.problems?.first?.name == "Elektra")
    #expect(problem.project?.gym?.name == "Klätterverket")
}

@Test func markSentIfActiveOnlyMovesActiveProjects() {
    let active = Project(name: "Elektra")
    active.markSentIfActive()
    #expect(active.status == .sent)

    let archived = Project(name: "Old Wall", status: .archived)
    archived.markSentIfActive()
    #expect(archived.status == .archived)
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test -project BoulderTracker.xcodeproj -scheme BoulderTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet -only-testing:BoulderTrackerTests/ModelRoundTripTests`
Expected: compile failure — `cannot find 'Project' in scope`.

- [ ] **Step 3: Create `BoulderTracker/Models/ProjectStatus.swift`**

```swift
import Foundation

/// Lifecycle of a climbing project. `archived` hides a project the user is
/// done with — a reset wall, a lost interest — without touching the attempts
/// logged against it.
enum ProjectStatus: String, Codable, CaseIterable, Identifiable {
    case active
    case sent
    case archived

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .active: "Active"
        case .sent: "Sent"
        case .archived: "Archived"
        }
    }
}
```

- [ ] **Step 4: Create `BoulderTracker/Models/Project.swift`**

```swift
import Foundation
import SwiftData

// Defaults on every attribute keep the model CloudKit-compatible; see the
// note at the top of `Session`.
@Model
final class Project {
    var name: String = ""
    var colorGrade: ColorGrade = ColorGrade.unknown
    var status: ProjectStatus = ProjectStatus.active
    var notes: String?
    var createdDate: Date = Date.now
    /// The one project pinned to the Home card. `ProjectSelection` is the
    /// only writer, so exactly one row carries it.
    var isCurrent: Bool = false
    var isSampleData: Bool = false
    var gym: Gym?
    /// Explicit inverse: CloudKit-backed stores require one on every
    /// relationship. Deleting a project nulls the link and leaves every
    /// logged attempt on its session.
    @Relationship(deleteRule: .nullify, inverse: \SessionProblem.project)
    var problems: [SessionProblem]? = []

    init(name: String, colorGrade: ColorGrade = .unknown, gym: Gym? = nil,
         status: ProjectStatus = .active, createdDate: Date = .now) {
        self.name = name
        self.colorGrade = colorGrade
        self.gym = gym
        self.status = status
        self.createdDate = createdDate
    }

    /// A logged send completes the project. Sent and archived rows keep the
    /// status the user chose, so a repeat ascent never resurrects one.
    func markSentIfActive() {
        guard status == .active else { return }
        status = .sent
    }
}
```

- [ ] **Step 5: Add the relationship to `SessionProblem`**

In `BoulderTracker/Models/SessionProblem.swift`, directly below `var session: Session?`:

```swift
    var project: Project?
```

Replace the doc comment on `isProject` with:

```swift
    /// Legacy flag, read only by `ProjectBackfill`. Kept in the schema until
    /// every device has migrated to `project`; deleting an attribute while
    /// older peers still sync the old CloudKit schema drops their writes.
    var isProject: Bool = false
```

- [ ] **Step 6: Register the model in both schemas**

`BoulderTracker/App/BoulderTrackerApp.swift:29-32` becomes:

```swift
        let schema = Schema([
            Session.self, SessionProblem.self, Gym.self, Partner.self,
            RoadmapProgress.self, Achievement.self, Shoe.self, Project.self,
        ])
```

`BoulderTrackerTests/ModelRoundTripTests.swift:10-13` becomes:

```swift
    let schema = Schema([
        Session.self, SessionProblem.self, Gym.self, Partner.self,
        RoadmapProgress.self, Achievement.self, Shoe.self, Project.self,
    ])
```

- [ ] **Step 7: Regenerate the Xcode project and run the tests**

```bash
xcodegen generate
xcodebuild test -project BoulderTracker.xcodeproj -scheme BoulderTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet -only-testing:BoulderTrackerTests/ModelRoundTripTests
```
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add BoulderTracker/Models/Project.swift BoulderTracker/Models/ProjectStatus.swift \
        BoulderTracker/Models/SessionProblem.swift BoulderTracker/App/BoulderTrackerApp.swift \
        BoulderTrackerTests/ModelRoundTripTests.swift BoulderTracker.xcodeproj/project.pbxproj
git commit -m "feat: add stored Project model linked to session problems"
```

---

### Task 2: ProjectStats

**Files:**
- Create: `BoulderTracker/Stats/ProjectStats.swift`
- Test: `BoulderTrackerTests/ProjectStatsTests.swift`

**Interfaces:**
- Consumes: `Project`, `SessionProblem.totalLogs`, `Array.persisted`.
- Produces: `ProjectStats(project:)` with `sessionCount: Int`, `attemptCount: Int`, `lastAttemptDate: Date?`.

- [ ] **Step 1: Write the failing test**

Create `BoulderTrackerTests/ProjectStatsTests.swift`:

```swift
import Testing
import Foundation
import SwiftData
@testable import BoulderTracker

@MainActor
struct ProjectStatsTests {
    private func makeSession(daysAgo: Int, context: ModelContext) -> Session {
        let start = Date.now.addingTimeInterval(TimeInterval(-daysAgo) * 24 * 3600)
        let session = Session(startTime: start, gym: nil, partners: [])
        context.insert(session)
        return session
    }

    @Test func countsDistinctSessionsNotProblemRows() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let project = Project(name: "Elektra")
        context.insert(project)
        let firstSession = makeSession(daysAgo: 6, context: context)
        let secondSession = makeSession(daysAgo: 2, context: context)
        for session in [firstSession, firstSession, secondSession] {
            let problem = SessionProblem(name: "Elektra", colorGrade: .red, styles: [], fallCount: 2)
            session.problems.append(problem)
            problem.project = project
        }
        try context.save()

        let stats = ProjectStats(project: project)

        #expect(stats.sessionCount == 2)
        #expect(stats.attemptCount == 6)
        #expect(stats.lastAttemptDate == secondSession.startTime)
    }

    @Test func emptyProjectHasNoAttempts() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let project = Project(name: "Fresh")
        context.insert(project)
        try context.save()

        let stats = ProjectStats(project: project)

        #expect(stats.sessionCount == 0)
        #expect(stats.attemptCount == 0)
        #expect(stats.lastAttemptDate == nil)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test -project BoulderTracker.xcodeproj -scheme BoulderTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet -only-testing:BoulderTrackerTests/ProjectStatsTests`
Expected: compile failure — `cannot find 'ProjectStats' in scope`.

- [ ] **Step 3: Create `BoulderTracker/Stats/ProjectStats.swift`**

```swift
import Foundation

/// Attempt history of a project, read from the session problems linked to it.
/// The project row owns identity and status; sessions still own the logs.
struct ProjectStats {
    let sessionCount: Int
    let attemptCount: Int
    let lastAttemptDate: Date?

    init(project: Project) {
        let problems = (project.problems ?? []).persisted
        sessionCount = Set(problems.compactMap { $0.session?.persistentModelID }).count
        attemptCount = problems.reduce(0) { $0 + $1.totalLogs }
        lastAttemptDate = problems.compactMap { $0.session?.startTime }.max()
    }
}
```

- [ ] **Step 4: Regenerate and run the tests**

```bash
xcodegen generate
xcodebuild test -project BoulderTracker.xcodeproj -scheme BoulderTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet -only-testing:BoulderTrackerTests/ProjectStatsTests
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add BoulderTracker/Stats/ProjectStats.swift BoulderTrackerTests/ProjectStatsTests.swift \
        BoulderTracker.xcodeproj/project.pbxproj
git commit -m "feat: add ProjectStats over linked session problems"
```

---

### Task 3: ProjectSelection

**Files:**
- Create: `BoulderTracker/Services/ProjectSelection.swift`
- Test: `BoulderTrackerTests/ProjectSelectionTests.swift`

**Interfaces:**
- Consumes: `Project`, `ProjectStats`.
- Produces: `ProjectSelection.makeCurrent(_ project: Project, in context: ModelContext)` and `ProjectSelection.current(from projects: [Project]) -> Project?`. Neither saves; callers save.

- [ ] **Step 1: Write the failing test**

Create `BoulderTrackerTests/ProjectSelectionTests.swift`:

```swift
import Testing
import Foundation
import SwiftData
@testable import BoulderTracker

@MainActor
struct ProjectSelectionTests {
    @Test func makeCurrentLeavesExactlyOneCurrentProject() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let first = Project(name: "Elektra")
        first.isCurrent = true
        let second = Project(name: "Moonwalk")
        context.insert(first)
        context.insert(second)
        try context.save()

        ProjectSelection.makeCurrent(second, in: context)
        try context.save()

        #expect(second.isCurrent)
        #expect(first.isCurrent == false)
    }

    @Test func makeCurrentIgnoresSentAndArchivedProjects() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let sent = Project(name: "Done", status: .sent)
        context.insert(sent)
        try context.save()

        ProjectSelection.makeCurrent(sent, in: context)

        #expect(sent.isCurrent == false)
    }

    @Test func currentPrefersThePinnedActiveProject() {
        let pinned = Project(name: "Pinned")
        pinned.isCurrent = true
        let other = Project(name: "Other")

        #expect(ProjectSelection.current(from: [other, pinned])?.name == "Pinned")
    }

    @Test func currentFallsBackToMostWorkedActiveProject() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let quiet = Project(name: "Quiet")
        let worked = Project(name: "Worked")
        context.insert(quiet)
        context.insert(worked)
        for daysAgo in [5, 3] {
            let start = Date.now.addingTimeInterval(TimeInterval(-daysAgo) * 24 * 3600)
            let session = Session(startTime: start, gym: nil, partners: [])
            context.insert(session)
            let problem = SessionProblem(name: "Worked", colorGrade: .red, styles: [], fallCount: 1)
            session.problems.append(problem)
            problem.project = worked
        }
        try context.save()

        #expect(ProjectSelection.current(from: [quiet, worked])?.name == "Worked")
    }

    @Test func currentIgnoresArchivedAndSentProjects() {
        let archived = Project(name: "Archived", status: .archived)
        let sent = Project(name: "Sent", status: .sent)

        #expect(ProjectSelection.current(from: [archived, sent]) == nil)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test -project BoulderTracker.xcodeproj -scheme BoulderTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet -only-testing:BoulderTrackerTests/ProjectSelectionTests`
Expected: compile failure — `cannot find 'ProjectSelection' in scope`.

- [ ] **Step 3: Create `BoulderTracker/Services/ProjectSelection.swift`**

```swift
import Foundation
import SwiftData

/// Single writer for `Project.isCurrent`, so the "one pinned project"
/// invariant lives in one place instead of at every call site.
enum ProjectSelection {
    /// Pins an active project to the Home card and unpins the rest. Sent and
    /// archived projects are not pinnable, so the card never shows finished
    /// work. Does not save; the caller does.
    static func makeCurrent(_ project: Project, in context: ModelContext) {
        guard project.status == .active else { return }
        let stored = (try? context.fetch(FetchDescriptor<Project>()))?.persisted ?? []
        for other in stored where other.persistentModelID != project.persistentModelID {
            other.isCurrent = false
        }
        project.isCurrent = true
    }

    /// The project the Home card shows: the user's pin when set, otherwise the
    /// active project worked in the most sessions, most recent breaking ties.
    static func current(from projects: [Project]) -> Project? {
        let active = projects.persisted.filter { $0.status == .active }
        if let pinned = active.first(where: \.isCurrent) { return pinned }
        return active.max { lhs, rhs in
            let lhsStats = ProjectStats(project: lhs)
            let rhsStats = ProjectStats(project: rhs)
            if lhsStats.sessionCount != rhsStats.sessionCount {
                return lhsStats.sessionCount < rhsStats.sessionCount
            }
            return (lhsStats.lastAttemptDate ?? .distantPast)
                < (rhsStats.lastAttemptDate ?? .distantPast)
        }
    }
}
```

- [ ] **Step 4: Regenerate and run the tests**

```bash
xcodegen generate
xcodebuild test -project BoulderTracker.xcodeproj -scheme BoulderTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet -only-testing:BoulderTrackerTests/ProjectSelectionTests
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add BoulderTracker/Services/ProjectSelection.swift \
        BoulderTrackerTests/ProjectSelectionTests.swift BoulderTracker.xcodeproj/project.pbxproj
git commit -m "feat: add single-writer current project selection"
```

---

### Task 4: Auto-complete a project on a logged send

**Files:**
- Modify: `BoulderTracker/Models/SessionProblem.swift` (`recordResult`)
- Test: `BoulderTrackerTests/AttemptResultTests.swift`

**Interfaces:**
- Consumes: `Project.markSentIfActive()`.
- Produces: no new symbols. `SessionProblem.recordResult(_:)` now also completes a linked active project.

`recordResult` is the one choke point every logging path goes through — `ProblemTile`, `QuickLogRow`, and the watch sync inbox — so no caller can forget the status update.

- [ ] **Step 1: Write the failing test**

Append to `BoulderTrackerTests/AttemptResultTests.swift`:

```swift
    @Test func loggingASendCompletesTheLinkedProject() {
        let project = Project(name: "Elektra")
        let problem = SessionProblem(name: "Elektra", colorGrade: .red, styles: [])
        problem.project = project

        problem.recordResult(.send)

        #expect(project.status == .sent)
    }

    @Test func loggingAFallLeavesTheProjectActive() {
        let project = Project(name: "Elektra")
        let problem = SessionProblem(name: "Elektra", colorGrade: .red, styles: [])
        problem.project = project

        problem.recordResult(.fall)

        #expect(project.status == .active)
    }

    @Test func loggingASendLeavesAnArchivedProjectArchived() {
        let project = Project(name: "Elektra", status: .archived)
        let problem = SessionProblem(name: "Elektra", colorGrade: .red, styles: [])
        problem.project = project

        problem.recordResult(.flash)

        #expect(project.status == .archived)
    }
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test -project BoulderTracker.xcodeproj -scheme BoulderTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet -only-testing:BoulderTrackerTests/AttemptResultTests`
Expected: FAIL — `Expectation failed: (project.status → .active) == .sent`.

- [ ] **Step 3: Update `recordResult` in `BoulderTracker/Models/SessionProblem.swift`**

```swift
    func recordResult(_ result: AttemptResult) {
        switch result {
        case .flash: flashCount += 1
        case .send: sendCount += 1
        case .fall: fallCount += 1
        }
        if result != .fall { project?.markSentIfActive() }
    }
```

If `AttemptResult` is not `Equatable`, use `if case .fall = result {} else { project?.markSentIfActive() }` instead — check `Shared/` or `BoulderTracker/Models/` for the declaration before writing the line.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `xcodebuild test -project BoulderTracker.xcodeproj -scheme BoulderTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet -only-testing:BoulderTrackerTests/AttemptResultTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add BoulderTracker/Models/SessionProblem.swift BoulderTrackerTests/AttemptResultTests.swift
git commit -m "feat: complete a linked project when a send is logged"
```

---

### Task 5: Backfill stored projects from derived groups

**Files:**
- Create: `BoulderTracker/Services/ProjectBackfill.swift`
- Modify: `BoulderTracker/App/BoulderTrackerApp.swift:22` (call the backfill at launch)
- Modify: `BoulderTracker/Services/SampleDataGenerator.swift` (`removeSampleData` deletes sample projects)
- Test: `BoulderTrackerTests/ProjectBackfillTests.swift`

**Interfaces:**
- Consumes: `Project`, `ProjectStatus`, `SessionProblem.isProject`.
- Produces: `ProjectBackfill.completedFlagKey: String`, `ProjectBackfill.runIfNeeded(context:defaults:)`, `ProjectBackfill.backfillProjects(in context: ModelContext) throws`.

The legacy grouping rule lives privately inside `ProjectBackfill` — copied from `ProjectAggregator`, which Task 8 deletes. That duplication is deliberate and temporary: the backfill must keep reading the old rule after its original home is gone.

- [ ] **Step 1: Write the failing test**

Create `BoulderTrackerTests/ProjectBackfillTests.swift`:

```swift
import Testing
import Foundation
import SwiftData
@testable import BoulderTracker

@MainActor
struct ProjectBackfillTests {
    private func makeSession(daysAgo: Int, gym: Gym?, context: ModelContext) -> Session {
        let start = Date.now.addingTimeInterval(TimeInterval(-daysAgo) * 24 * 3600)
        let session = Session(startTime: start, gym: gym, partners: [])
        context.insert(session)
        return session
    }

    @Test func createsOneProjectPerDerivedGroupAndClearsTheLegacyFlag() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let gym = Gym(name: "Klätterverket")
        context.insert(gym)
        let session = makeSession(daysAgo: 3, gym: gym, context: context)
        let marked = SessionProblem(name: "Elektra", colorGrade: .red, styles: [])
        marked.isProject = true
        let repeated = SessionProblem(name: "Moonwalk", colorGrade: .blue, styles: [], fallCount: 3)
        let ignored = SessionProblem(name: "Warmup", colorGrade: .green, styles: [], sendCount: 1)
        session.problems = [marked, repeated, ignored]
        try context.save()

        try ProjectBackfill.backfillProjects(in: context)

        let projects = try context.fetch(FetchDescriptor<Project>())
        #expect(Set(projects.map(\.name)) == ["Elektra", "Moonwalk"])
        #expect(projects.allSatisfy { $0.gym?.name == "Klätterverket" })
        #expect(projects.allSatisfy { $0.status == .active })
        #expect(marked.project?.name == "Elektra")
        #expect(marked.isProject == false)
        #expect(ignored.project == nil)
    }

    @Test func marksSentGroupsAsSent() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let session = makeSession(daysAgo: 1, gym: nil, context: context)
        let problem = SessionProblem(name: "Elektra", colorGrade: .red, styles: [],
                                     sendCount: 1, fallCount: 4)
        problem.isProject = true
        session.problems = [problem]
        try context.save()

        try ProjectBackfill.backfillProjects(in: context)

        #expect(try context.fetch(FetchDescriptor<Project>()).first?.status == .sent)
    }

    @Test func flagsProjectsBuiltOnlyFromSampleSessions() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let session = makeSession(daysAgo: 1, gym: nil, context: context)
        session.isSampleData = true
        let problem = SessionProblem(name: "Demo", colorGrade: .red, styles: [], fallCount: 2)
        session.problems = [problem]
        try context.save()

        try ProjectBackfill.backfillProjects(in: context)

        #expect(try context.fetch(FetchDescriptor<Project>()).first?.isSampleData == true)
    }

    @Test func secondRunCreatesNoDuplicates() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let session = makeSession(daysAgo: 1, gym: nil, context: context)
        let problem = SessionProblem(name: "Elektra", colorGrade: .red, styles: [], fallCount: 2)
        session.problems = [problem]
        try context.save()

        try ProjectBackfill.backfillProjects(in: context)
        try ProjectBackfill.backfillProjects(in: context)

        #expect(try context.fetchCount(FetchDescriptor<Project>()) == 1)
    }

    @Test func runIfNeededSkipsWorkOnceTheFlagIsSet() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let session = makeSession(daysAgo: 1, gym: nil, context: context)
        session.problems = [SessionProblem(name: "Elektra", colorGrade: .red, styles: [], fallCount: 2)]
        try context.save()
        let defaults = UserDefaults(suiteName: "ProjectBackfillTests")!
        defaults.removePersistentDomain(forName: "ProjectBackfillTests")

        ProjectBackfill.runIfNeeded(context: context, defaults: defaults)
        #expect(defaults.bool(forKey: ProjectBackfill.completedFlagKey))
        #expect(try context.fetchCount(FetchDescriptor<Project>()) == 1)

        let extraSession = makeSession(daysAgo: 0, gym: nil, context: context)
        extraSession.problems = [SessionProblem(name: "Later", colorGrade: .blue, styles: [], fallCount: 2)]
        try context.save()
        ProjectBackfill.runIfNeeded(context: context, defaults: defaults)

        #expect(try context.fetchCount(FetchDescriptor<Project>()) == 1)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test -project BoulderTracker.xcodeproj -scheme BoulderTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet -only-testing:BoulderTrackerTests/ProjectBackfillTests`
Expected: compile failure — `cannot find 'ProjectBackfill' in scope`.

- [ ] **Step 3: Create `BoulderTracker/Services/ProjectBackfill.swift`**

```swift
import Foundation
import OSLog
import SwiftData

/// One-time migration: projects used to be derived on the fly from session
/// problems. This turns every group that rule produced into a stored `Project`
/// row so the user can edit, complete, archive, and delete them.
enum ProjectBackfill {
    static let completedFlagKey = "pref.projectBackfillDone"

    /// Read once here rather than from `AppPreferences`, which drops the key
    /// as part of this migration.
    private static let legacyCurrentProjectNameKey = "pref.currentProjectName"

    static func runIfNeeded(context: ModelContext, defaults: UserDefaults) {
        guard !defaults.bool(forKey: completedFlagKey) else { return }
        do {
            try backfillProjects(in: context)
            adoptLegacyCurrentProject(in: context, defaults: defaults)
            defaults.set(true, forKey: completedFlagKey)
        } catch {
            // Retried on next launch because the flag stays unset.
            Logger.persistence.error("Project backfill failed: \(error)")
        }
    }

    static func backfillProjects(in context: ModelContext) throws {
        let sessions = try context.fetch(FetchDescriptor<Session>()).persisted
        let existingKeys = Set(
            try context.fetch(FetchDescriptor<Project>()).map {
                GroupKey(name: $0.name, gymName: $0.gym?.name)
            }
        )
        for (key, occurrences) in legacyGroups(in: sessions) where !existingKeys.contains(key) {
            context.insert(makeProject(named: key.name, from: occurrences))
        }
        for problem in sessions.flatMap(\.problems) {
            problem.isProject = false
        }
        try context.save()
    }

    private static func makeProject(named name: String,
                                    from occurrences: [SessionProblem]) -> Project {
        let latest = occurrences.max { attemptDate(of: $0) < attemptDate(of: $1) }
        let project = Project(
            name: name,
            colorGrade: latest?.colorGrade ?? .unknown,
            gym: latest?.session?.gym,
            status: occurrences.contains(where: \.wasSent) ? .sent : .active,
            createdDate: occurrences.map(attemptDate(of:)).min() ?? .now
        )
        project.isSampleData = occurrences.allSatisfy { $0.session?.isSampleData == true }
        project.problems = occurrences
        return project
    }

    /// The rule `ProjectAggregator` used before projects were stored: a named
    /// problem is a project when it was explicitly marked, or when it is
    /// unsent and has logged falls.
    private static func legacyGroups(in sessions: [Session]) -> [GroupKey: [SessionProblem]] {
        let named = sessions.flatMap(\.problems).filter { !$0.name.isEmpty }
        let byKey = Dictionary(grouping: named) {
            GroupKey(name: $0.name, gymName: $0.session?.gym?.name)
        }
        return byKey.filter { _, occurrences in
            let marked = occurrences.contains(where: \.isProject)
            let sent = occurrences.contains(where: \.wasSent)
            let hasFalls = occurrences.contains { $0.fallCount > 0 }
            return marked || (!sent && hasFalls)
        }
    }

    private static func adoptLegacyCurrentProject(in context: ModelContext,
                                                  defaults: UserDefaults) {
        guard let storedName = defaults.string(forKey: legacyCurrentProjectNameKey),
              !storedName.isEmpty,
              let match = try? context.fetch(FetchDescriptor<Project>())
                  .first(where: { $0.name == storedName && $0.status == .active })
        else { return }
        ProjectSelection.makeCurrent(match, in: context)
        context.saveReportingFailure(operation: "current project migration")
        defaults.removeObject(forKey: legacyCurrentProjectNameKey)
    }

    private static func attemptDate(of problem: SessionProblem) -> Date {
        problem.session?.startTime ?? .distantPast
    }

    private struct GroupKey: Hashable {
        let name: String
        let gymName: String?
    }
}
```

If `saveReportingFailure` is not visible from a non-view type, replace that line with `try? context.save()` — check its declaration first (`grep -rn "func saveReportingFailure" BoulderTracker`).

- [ ] **Step 4: Run the tests to verify they pass**

```bash
xcodegen generate
xcodebuild test -project BoulderTracker.xcodeproj -scheme BoulderTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet -only-testing:BoulderTrackerTests/ProjectBackfillTests
```
Expected: PASS.

- [ ] **Step 5: Call the backfill at launch**

In `BoulderTracker/App/BoulderTrackerApp.swift`, directly after the `AchievementCleanup.removeUnearnedOnce(...)` line:

```swift
        ProjectBackfill.runIfNeeded(context: container.mainContext, defaults: .standard)
```

- [ ] **Step 6: Purge sample projects with the rest of the demo data**

In `BoulderTracker/Services/SampleDataGenerator.swift`, inside `removeSampleData(from:)`, directly before `try context.save()`:

```swift
        let sampleProjects = try context.fetch(
            FetchDescriptor<Project>(predicate: #Predicate { $0.isSampleData })
        )
        for project in sampleProjects {
            context.delete(project)
        }
```

- [ ] **Step 7: Build and run the whole suite**

Run: `xcodebuild test -project BoulderTracker.xcodeproj -scheme BoulderTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`
Expected: PASS (the existing `StatsAggregatorTests` project cases still pass — `ProjectAggregator` is untouched until Task 8).

- [ ] **Step 8: Commit**

```bash
git add BoulderTracker/Services/ProjectBackfill.swift BoulderTracker/App/BoulderTrackerApp.swift \
        BoulderTracker/Services/SampleDataGenerator.swift \
        BoulderTrackerTests/ProjectBackfillTests.swift BoulderTracker.xcodeproj/project.pbxproj
git commit -m "feat: backfill stored projects from derived groups at launch"
```

---

### Task 6a: Extract the grade picker (refactor only)

**Files:**
- Create: `BoulderTracker/Design/GradePicker.swift`
- Modify: `BoulderTracker/Home/QuickAddProblemSheet.swift` (delete `gradePills` / `gradePill`, use the new view)

**Interfaces:**
- Consumes: `ColorGrade.displayOrder`, `GradeDot`, `FlowLayout`.
- Produces: `GradePicker(selection: Binding<ColorGrade>)`.

Structure only — no behaviour change, and it ships as its own commit. Task 6b needs the same pill row, and copying it would duplicate it across two files.

- [ ] **Step 1: Create `BoulderTracker/Design/GradePicker.swift`**

Move the two private members verbatim out of `QuickAddProblemSheet` (lines 63-95) into:

```swift
import SwiftUI

/// Wrapping row of selectable grade pills, shared by the problem and project
/// editors.
struct GradePicker: View {
    @Environment(\.palette) private var palette
    @Environment(\.gradeSystem) private var gradeSystem
    @Binding var selection: ColorGrade

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(ColorGrade.displayOrder) { grade in
                gradePill(grade)
            }
        }
    }

    private func gradePill(_ grade: ColorGrade) -> some View {
        let isSelected = selection == grade
        return Button {
            selection = grade
        } label: {
            HStack(spacing: 7) {
                GradeDot(grade: grade, size: 11)
                Text(grade.shortLabel(in: gradeSystem))
                    .scaledFont(size: 13, weight: .semibold)
                    .foregroundStyle(isSelected ? palette.text : palette.textDim)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(isSelected ? palette.pillActive : palette.pill)
            .clipShape(.capsule)
            .overlay {
                if isSelected {
                    Capsule().strokeBorder(ThemePalette.accent, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(grade.shortLabel(in: gradeSystem))
    }
}
```

- [ ] **Step 2: Use it in `QuickAddProblemSheet`**

Delete the `gradePills` and `gradePill(_:)` members. Change the grade field to:

```swift
                field(label: "Grade") { GradePicker(selection: $selectedGrade) }
```

- [ ] **Step 3: Build and run the suite**

```bash
xcodegen generate
xcodebuild test -project BoulderTracker.xcodeproj -scheme BoulderTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
```
Expected: PASS, no behaviour change.

- [ ] **Step 4: Commit**

```bash
git add BoulderTracker/Design/GradePicker.swift BoulderTracker/Home/QuickAddProblemSheet.swift \
        BoulderTracker.xcodeproj/project.pbxproj
git commit -m "refactor: extract shared GradePicker from QuickAddProblemSheet"
```

---

### Task 6b: ProjectEditorSheet

**Files:**
- Create: `BoulderTracker/Home/ProjectEditorSheet.swift`

**Interfaces:**
- Consumes: `Project`, `ProjectStatus`, `GradePicker`, `SelectablePill`, `ThemedTextField`, `ThemedNotesField`, `AccentButtonLabel`, `SectionHeading`, `ProjectSelection`.
- Produces: `ProjectEditorSheet(project: Project?)` — `nil` creates.

Modelled on `ShoeEditorSheet` (`BoulderTracker/Profile/ShoeListSection.swift:79-152`): same field layout, same save/delete shape, same confirmation dialog.

- [ ] **Step 1: Create the file**

```swift
import SwiftUI
import SwiftData

struct ProjectEditorSheet: View {
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var gyms: [Gym]
    /// `nil` creates a new project.
    let project: Project?

    @State private var name = ""
    @State private var selectedGrade: ColorGrade = .green
    @State private var selectedGym: Gym?
    @State private var status: ProjectStatus = .active
    @State private var notes = ""
    @State private var confirmingDelete = false

    /// Natural order so "Wall 2" sorts before "Wall 10".
    private var sortedGyms: [Gym] {
        gyms.persisted.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(project == nil ? "Add Project" : "Edit Project")
                    .scaledFont(size: 18, weight: .bold)
                    .foregroundStyle(palette.text)
                field(label: "Name") {
                    ThemedTextField(placeholder: "e.g. Elektra", text: $name)
                }
                field(label: "Grade") { GradePicker(selection: $selectedGrade) }
                field(label: "Gym") { gymPills }
                field(label: "Status") { statusPills }
                field(label: "Notes") {
                    ThemedNotesField(placeholder: "Beta, conditions, plans", text: $notes)
                }
                Button(action: saveProject) {
                    AccentButtonLabel(title: "Save")
                }
                .buttonStyle(.plain)
                .disabled(name.isEmpty)
                if project != nil {
                    deleteButton
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 26)
            .padding(.bottom, 28)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .confirmationDialog(
            "Delete this project?", isPresented: $confirmingDelete, titleVisibility: .visible
        ) {
            Button("Delete Project", role: .destructive, action: deleteProject)
        } message: {
            Text("Sessions keep every logged attempt; only the project is removed.")
        }
        .onAppear(perform: loadProject)
    }

    private func field(label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(title: label)
            content()
        }
    }

    private var gymPills: some View {
        FlowLayout(spacing: 8) {
            ForEach(sortedGyms) { gym in
                SelectablePill(title: gym.name, isSelected: selectedGym == gym) {
                    selectedGym = selectedGym == gym ? nil : gym
                }
            }
        }
    }

    private var statusPills: some View {
        HStack(spacing: 8) {
            ForEach(ProjectStatus.allCases) { option in
                SelectablePill(title: option.displayName, isSelected: status == option) {
                    status = option
                }
            }
        }
    }

    private var deleteButton: some View {
        Button {
            confirmingDelete = true
        } label: {
            Text("Delete Project")
                .scaledFont(size: 14, weight: .semibold)
                .foregroundStyle(ThemePalette.danger)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private func loadProject() {
        guard let project, !project.isInvalidated else { return }
        name = project.name
        selectedGrade = project.colorGrade
        selectedGym = project.gym
        status = project.status
        notes = project.notes ?? ""
    }

    private func saveProject() {
        let target = project ?? {
            let created = Project(name: name)
            modelContext.insert(created)
            return created
        }()
        target.name = name
        target.colorGrade = selectedGrade
        target.gym = selectedGym
        target.status = status
        target.notes = notes.isEmpty ? nil : notes
        if status != .active { target.isCurrent = false }
        modelContext.saveReportingFailure(operation: "project save")
        dismiss()
    }

    private func deleteProject() {
        guard let project else { return }
        modelContext.delete(project)
        modelContext.saveReportingFailure(operation: "project delete")
        dismiss()
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodegen generate
xcodebuild build -project BoulderTracker.xcodeproj -scheme BoulderTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
```
Expected: BUILD SUCCEEDED. If `ThemedNotesField`'s initializer differs, match the call in `QuickAddProblemSheet.swift:31`.

- [ ] **Step 3: Commit**

```bash
git add BoulderTracker/Home/ProjectEditorSheet.swift BoulderTracker.xcodeproj/project.pbxproj
git commit -m "feat: add project editor sheet"
```

---

### Task 7: Rewrite ProjectsSheet against stored projects

**Files:**
- Modify: `BoulderTracker/Home/ProjectsSheet.swift` (full rewrite)
- Modify: `BoulderTracker/Home/CurrentProjectCard.swift:50` (drop the argument at the one call site)

**Interfaces:**
- Consumes: `Project`, `ProjectStats`, `ProjectSelection`, `ProjectEditorSheet`, `HoldIcon`.
- Produces: `ProjectsSheet()` — no initializer arguments.

- [ ] **Step 1: Replace the file contents**

```swift
import SwiftUI
import SwiftData

/// Every stored project, grouped by lifecycle, with add / edit / pin controls.
struct ProjectsSheet: View {
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var modelContext
    @Query private var projects: [Project]
    @State private var editingProject: Project?
    @State private var isAddingProject = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if projects.persisted.isEmpty {
                    emptyState
                }
                ForEach(ProjectStatus.allCases) { status in
                    section(for: status)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 26)
            .padding(.bottom, 28)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(item: $editingProject) { project in
            ProjectEditorSheet(project: project)
        }
        .sheet(isPresented: $isAddingProject) {
            ProjectEditorSheet(project: nil)
        }
    }

    private var header: some View {
        HStack {
            Text("Projects")
                .scaledFont(size: 18, weight: .bold)
                .foregroundStyle(palette.text)
            Spacer()
            Button {
                isAddingProject = true
            } label: {
                Text("+ Add")
                    .scaledFont(size: 14, weight: .semibold)
                    .foregroundStyle(palette.accentText)
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyState: some View {
        Text("No projects yet. Add one here, or mark a problem as a project while logging a session.")
            .scaledFont(size: 14)
            .foregroundStyle(palette.textDim)
    }

    @ViewBuilder
    private func section(for status: ProjectStatus) -> some View {
        let matching = projectsSorted(withStatus: status)
        if !matching.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeading(title: status.displayName)
                ForEach(matching) { project in
                    projectRow(project)
                }
            }
        }
    }

    /// Most recently worked first; never-attempted projects sort by creation.
    private func projectsSorted(withStatus status: ProjectStatus) -> [Project] {
        projects.persisted
            .filter { $0.status == status }
            .sorted { lhs, rhs in
                let lhsDate = ProjectStats(project: lhs).lastAttemptDate ?? lhs.createdDate
                let rhsDate = ProjectStats(project: rhs).lastAttemptDate ?? rhs.createdDate
                return lhsDate > rhsDate
            }
    }

    private func projectRow(_ project: Project) -> some View {
        Button {
            editingProject = project
        } label: {
            HStack(spacing: 12) {
                HoldIcon(grade: project.colorGrade, size: 40)
                ProjectRowSummary(project: project)
                Spacer()
                trailingControl(project)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .themedCard(cornerRadius: 16, sunken: true)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func trailingControl(_ project: Project) -> some View {
        switch project.status {
        case .sent:
            statusChip(text: "Sent", color: ThemePalette.success)
        case .archived:
            statusChip(text: "Archived", color: palette.textFaint)
        case .active where project.isCurrent:
            statusChip(text: "Current", color: palette.accentText)
        case .active:
            Button {
                ProjectSelection.makeCurrent(project, in: modelContext)
                modelContext.saveReportingFailure(operation: "set current project")
            } label: {
                Text("Set current")
                    .scaledFont(size: 12, weight: .semibold)
                    .foregroundStyle(palette.textDim)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(palette.pill)
                    .clipShape(.capsule)
            }
            .buttonStyle(.plain)
        }
    }

    private func statusChip(text: String, color: Color) -> some View {
        Text(text)
            .scaledFont(size: 12, weight: .semibold)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.16))
            .clipShape(.capsule)
    }
}

/// Name plus the grade / gym / session-count line under it.
private struct ProjectRowSummary: View {
    @Environment(\.palette) private var palette
    @Environment(\.gradeSystem) private var gradeSystem
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(project.name)
                .scaledFont(size: 15, weight: .semibold)
                .foregroundStyle(palette.text)
            Text(subtitle)
                .scaledFont(size: 12)
                .foregroundStyle(palette.textFaint)
        }
    }

    private var subtitle: String {
        let sessionCount = ProjectStats(project: project).sessionCount
        let sessionsLabel = sessionCount == 1 ? "1 session" : "\(sessionCount) sessions"
        let gymLabel = project.gym?.name ?? "Unknown gym"
        return "\(project.colorGrade.shortLabel(in: gradeSystem)) · \(gymLabel) · \(sessionsLabel)"
    }
}
```

- [ ] **Step 2: Keep the one call site compiling**

`BoulderTracker/Home/CurrentProjectCard.swift:50` becomes:

```swift
            ProjectsSheet()
```

The card itself still reads `ProjectAggregator`; Task 8 rewrites it. This
one-line change only keeps the build green.

- [ ] **Step 3: Build and run the whole suite**

```bash
xcodebuild test -project BoulderTracker.xcodeproj -scheme BoulderTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
```
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add BoulderTracker/Home/ProjectsSheet.swift BoulderTracker/Home/CurrentProjectCard.swift
git commit -m "feat: rewrite projects sheet against stored projects"
```

---

### Task 8: Migrate the Home card and delete ProjectAggregator

**Files:**
- Modify: `BoulderTracker/Home/CurrentProjectCard.swift` (full rewrite)
- Modify: `BoulderTracker/Home/HomeIdleView.swift:31` (drop the argument)
- Modify: `BoulderTracker/App/AppPreferences.swift:9` (remove `currentProjectNameKey`)
- Delete: `BoulderTracker/Stats/ProjectAggregator.swift`
- Modify: `BoulderTrackerTests/StatsAggregatorTests.swift:165-220` (drop the `ProjectAggregator` cases)

**Interfaces:**
- Consumes: `ProjectSelection.current(from:)`, `ProjectStats`, `ProjectsSheet()`.
- Produces: `CurrentProjectCard()` — no initializer arguments.

`ProjectGroup` and `ProjectAggregator` have no remaining readers after this task: `ProjectBackfill` carries its own copy of the legacy rule (Task 5).

- [ ] **Step 1: Rewrite `CurrentProjectCard.swift`**

```swift
import SwiftUI
import SwiftData

struct CurrentProjectCard: View {
    @Environment(\.palette) private var palette
    @Environment(\.gradeSystem) private var gradeSystem
    @Query private var projects: [Project]

    @State private var showingProjects = false

    private var project: Project? {
        ProjectSelection.current(from: projects)
    }

    var body: some View {
        Button {
            showingProjects = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Current Project")
                        .scaledFont(size: 14, weight: .semibold)
                        .foregroundStyle(palette.textFaint)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .scaledFont(size: 12, weight: .semibold)
                        .foregroundStyle(palette.textFaint)
                }
                if let project {
                    HStack(spacing: 12) {
                        HoldIcon(grade: project.colorGrade, size: 44)
                        projectDescription(project)
                    }
                } else {
                    Text("No active project — tap to add one")
                        .scaledFont(size: 13)
                        .foregroundStyle(palette.textDim)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .themedCard(cornerRadius: 18)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingProjects) {
            ProjectsSheet()
        }
    }

    private func projectDescription(_ project: Project) -> some View {
        let sessionCount = ProjectStats(project: project).sessionCount
        let sessionsLabel = sessionCount == 1
            ? "1 session on this problem"
            : "\(sessionCount) sessions on this problem"
        return VStack(alignment: .leading, spacing: 2) {
            Text("\(project.colorGrade.detailLabel(in: gradeSystem)) · \u{201C}\(project.name)\u{201D}")
                .scaledFont(size: 16, weight: .semibold)
                .foregroundStyle(palette.text)
            Text("\(project.gym?.name ?? "Unknown gym") · \(sessionsLabel)")
                .scaledFont(size: 13)
                .foregroundStyle(palette.textDim)
        }
    }
}
```

- [ ] **Step 2: Update the call site and drop the preference key**

`BoulderTracker/Home/HomeIdleView.swift:31` becomes:

```swift
            CurrentProjectCard()
```

Delete line 9 of `BoulderTracker/App/AppPreferences.swift`:

```swift
    static let currentProjectNameKey = "pref.currentProjectName"
```

- [ ] **Step 3: Delete the aggregator and its tests**

```bash
git rm BoulderTracker/Stats/ProjectAggregator.swift
```

In `BoulderTrackerTests/StatsAggregatorTests.swift`, delete every test that calls `ProjectAggregator` (the block around lines 165-220, covering `currentProject` and `groups`). Their replacements already exist in `ProjectStatsTests` and `ProjectSelectionTests`. Delete any helper left unused by that removal.

- [ ] **Step 4: Build and run the whole suite**

```bash
xcodegen generate
xcodebuild test -project BoulderTracker.xcodeproj -scheme BoulderTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
```
Expected: PASS. Confirm no references remain: `grep -rn "ProjectAggregator\|ProjectGroup\|currentProjectNameKey" --include='*.swift' .` prints nothing.

- [ ] **Step 5: Commit**

```bash
git add -A BoulderTracker/Home/CurrentProjectCard.swift BoulderTracker/Home/HomeIdleView.swift \
        BoulderTracker/App/AppPreferences.swift BoulderTracker/Stats/ProjectAggregator.swift \
        BoulderTrackerTests/StatsAggregatorTests.swift BoulderTracker.xcodeproj/project.pbxproj
git commit -m "feat: read the home project card from stored projects"
```

---

### Task 9: Link projects when marking a problem

**Files:**
- Create: `BoulderTracker/Services/ProjectLinking.swift`
- Modify: `BoulderTracker/Home/ProblemTile.swift:35-45` (context menu)
- Modify: `BoulderTracker/Home/QuickAddProblemSheet.swift` (`saveProblem`)
- Modify: `BoulderTracker/Models/SessionProblem.swift` (drop `isProject` from `init`)
- Test: `BoulderTrackerTests/ProjectLinkingTests.swift`

**Interfaces:**
- Consumes: `Project`, `ProjectStatus`.
- Produces: `ProjectLinking.linkProject(to problem: SessionProblem, in context: ModelContext) -> Project?` (discardable) and `ProjectLinking.unlinkProject(from problem: SessionProblem)`.

- [ ] **Step 1: Write the failing test**

Create `BoulderTrackerTests/ProjectLinkingTests.swift`:

```swift
import Testing
import Foundation
import SwiftData
@testable import BoulderTracker

@MainActor
struct ProjectLinkingTests {
    private func makeProblem(named name: String, gym: Gym?,
                             context: ModelContext) -> SessionProblem {
        let session = Session(startTime: .now, gym: gym, partners: [])
        context.insert(session)
        let problem = SessionProblem(name: name, colorGrade: .red, styles: [])
        session.problems.append(problem)
        return problem
    }

    @Test func createsAProjectForANamedProblem() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let gym = Gym(name: "Klätterverket")
        context.insert(gym)
        let problem = makeProblem(named: "Elektra", gym: gym, context: context)

        let project = ProjectLinking.linkProject(to: problem, in: context)

        #expect(project?.name == "Elektra")
        #expect(project?.gym?.name == "Klätterverket")
        #expect(project?.colorGrade == .red)
        #expect(problem.project === project)
    }

    @Test func reusesAnOpenProjectWithTheSameNameAndGym() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let gym = Gym(name: "Klätterverket")
        context.insert(gym)
        let first = makeProblem(named: "Elektra", gym: gym, context: context)
        let second = makeProblem(named: "Elektra", gym: gym, context: context)

        let firstProject = ProjectLinking.linkProject(to: first, in: context)
        let secondProject = ProjectLinking.linkProject(to: second, in: context)
        try context.save()

        #expect(firstProject === secondProject)
        #expect(try context.fetchCount(FetchDescriptor<Project>()) == 1)
    }

    @Test func doesNotReuseAnArchivedProject() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let archived = Project(name: "Elektra", status: .archived)
        context.insert(archived)
        let problem = makeProblem(named: "Elektra", gym: nil, context: context)

        let project = ProjectLinking.linkProject(to: problem, in: context)

        #expect(project !== archived)
    }

    @Test func refusesAnUnnamedProblem() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let problem = makeProblem(named: "", gym: nil, context: context)

        #expect(ProjectLinking.linkProject(to: problem, in: context) == nil)
        #expect(problem.project == nil)
    }

    @Test func unlinkClearsTheProject() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let problem = makeProblem(named: "Elektra", gym: nil, context: context)
        ProjectLinking.linkProject(to: problem, in: context)

        ProjectLinking.unlinkProject(from: problem)

        #expect(problem.project == nil)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test -project BoulderTracker.xcodeproj -scheme BoulderTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet -only-testing:BoulderTrackerTests/ProjectLinkingTests`
Expected: compile failure — `cannot find 'ProjectLinking' in scope`.

- [ ] **Step 3: Create `BoulderTracker/Services/ProjectLinking.swift`**

```swift
import Foundation
import SwiftData

/// Turns "mark this problem as a project" into a stored `Project`, reusing an
/// open one with the same name and gym so the same problem flagged in two
/// sessions stays a single project.
enum ProjectLinking {
    @discardableResult
    static func linkProject(to problem: SessionProblem, in context: ModelContext) -> Project? {
        guard !problem.name.isEmpty else { return nil }
        let project = openProject(named: problem.name, gym: problem.session?.gym, in: context)
            ?? insertProject(for: problem, in: context)
        problem.project = project
        return project
    }

    static func unlinkProject(from problem: SessionProblem) {
        problem.project = nil
    }

    private static func openProject(named name: String, gym: Gym?,
                                    in context: ModelContext) -> Project? {
        let stored = (try? context.fetch(FetchDescriptor<Project>()))?.persisted ?? []
        return stored.first {
            $0.status != .archived && $0.name == name && $0.gym?.name == gym?.name
        }
    }

    private static func insertProject(for problem: SessionProblem,
                                      in context: ModelContext) -> Project {
        let project = Project(
            name: problem.name,
            colorGrade: problem.colorGrade,
            gym: problem.session?.gym,
            status: problem.wasSent ? .sent : .active
        )
        project.isSampleData = problem.session?.isSampleData ?? false
        context.insert(project)
        return project
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
xcodegen generate
xcodebuild test -project BoulderTracker.xcodeproj -scheme BoulderTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet -only-testing:BoulderTrackerTests/ProjectLinkingTests
```
Expected: PASS.

- [ ] **Step 5: Wire up the `ProblemTile` context menu**

Replace the first `Button` in the `.contextMenu` block of `BoulderTracker/Home/ProblemTile.swift` with:

```swift
            Button {
                toggleProjectLink()
            } label: {
                Label(
                    problem.project == nil ? "Mark as project" : "Remove project mark",
                    systemImage: problem.project == nil ? "flag" : "flag.slash"
                )
            }
            .disabled(problem.name.isEmpty)
```

Add the method next to `deleteProblem()`:

```swift
    /// A nameless quick log cannot become a project — there would be no way to
    /// find it again — so the menu item is disabled for one.
    private func toggleProjectLink() {
        if problem.project == nil {
            ProjectLinking.linkProject(to: problem, in: modelContext)
        } else {
            ProjectLinking.unlinkProject(from: problem)
        }
        modelContext.saveReportingFailure(operation: "project mark toggle")
    }
```

- [ ] **Step 6: Wire up `QuickAddProblemSheet`**

In `saveProblem()`, drop `isProject: isProject` from the `SessionProblem(...)` call and link after the problem joins the session:

```swift
    private func saveProblem() {
        let problem = SessionProblem(
            name: name, colorGrade: selectedGrade, styles: Array(selectedStyles)
        )
        if !notes.isEmpty { problem.notes = notes }
        if let photoData {
            problem.photoFilename = try? photoStore.savePhoto(photoData)
        }
        session.problems.append(problem)
        if isProject {
            ProjectLinking.linkProject(to: problem, in: modelContext)
        }
        modelContext.saveReportingFailure(operation: "problem add")
        dismiss()
    }
```

Change the toggle label so an unnamed problem cannot silently skip project creation:

```swift
                Toggle("Mark as project", isOn: $isProject)
                    .scaledFont(size: 15)
                    .foregroundStyle(palette.text)
                    .tint(ThemePalette.accent)
                    .disabled(name.isEmpty)
```

- [ ] **Step 7: Drop `isProject` from the `SessionProblem` initializer**

In `BoulderTracker/Models/SessionProblem.swift`, remove the `isProject: Bool = false` parameter and its `self.isProject = isProject` assignment. The stored property stays (see Global Constraints). Fix any test that passed the argument by setting `.isProject` directly instead.

- [ ] **Step 8: Build and run the whole suite**

```bash
xcodebuild test -project BoulderTracker.xcodeproj -scheme BoulderTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
```
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add BoulderTracker/Services/ProjectLinking.swift BoulderTracker/Home/ProblemTile.swift \
        BoulderTracker/Home/QuickAddProblemSheet.swift BoulderTracker/Models/SessionProblem.swift \
        BoulderTrackerTests BoulderTracker.xcodeproj/project.pbxproj
git commit -m "feat: link session problems to stored projects when marked"
```

---

### Task 10: Full verification

**Files:**
- Modify: none expected; fix whatever the checks surface.

**Interfaces:**
- Consumes: everything above.
- Produces: nothing.

- [ ] **Step 1: Confirm the old surface is gone**

```bash
grep -rn "ProjectAggregator\|ProjectGroup\|currentProjectNameKey" --include='*.swift' .
grep -rn "isProject" --include='*.swift' .
```
Expected: the first prints nothing. The second prints only the stored property and its doc comment in `SessionProblem.swift`, and the reads inside `ProjectBackfill.swift`.

- [ ] **Step 2: Run the iOS suite**

```bash
xcodebuild test -project BoulderTracker.xcodeproj -scheme BoulderTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
```
Expected: PASS.

- [ ] **Step 3: Build the watch target**

The watch shares `Shared/` and syncs session problems, so a schema change can break it.

```bash
xcodebuild build -project BoulderTracker.xcodeproj -scheme BoulderTrackerWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' -quiet
```
Expected: BUILD SUCCEEDED. If that simulator is absent, run `xcrun simctl list devices available | grep Watch` and substitute the newest available watch.

- [ ] **Step 4: Manual smoke test on the simulator**

Launch the app and confirm, in order:
1. Home shows the Current Project card populated from backfilled data (existing store) or the empty state (fresh install).
2. Tapping it opens the sheet with Active / Sent / Archived sections.
3. `+ Add` creates a project; it appears under Active.
4. Editing renames it and the Home card follows.
5. `Set current` moves the pin; only one row shows "Current".
6. Setting a project to Archived moves it into the Archived section and off the Home card.
7. During a live session, long-pressing a named problem tile marks it a project; the same menu item is greyed out on an unnamed quick log.
8. Logging a send on that problem moves its project to Sent.
9. Deleting a project from the editor leaves the session's logged attempts intact in the session detail sheet.

- [ ] **Step 5: Commit any fixes**

```bash
git add -A
git commit -m "fix: address project management verification findings"
```

Skip this step if steps 1-4 turned up nothing.
