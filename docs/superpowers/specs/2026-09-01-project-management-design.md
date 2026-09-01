# Project Management — Design

Date: 2026-09-01
Status: Approved for planning

## Problem

Projects in Boulder Tracker are derived, not stored. `ProjectAggregator.groups(in:)`
groups `SessionProblem` rows by `(name, gymName)` and keeps a group when any
occurrence has `isProject == true`, or when the problem is unsent and has at
least one logged fall. Nothing persists a project, so the user cannot:

- add a project before logging an attempt on it,
- rename one (the name lives on every `SessionProblem` row),
- mark one completed independently of send counts,
- remove one — clearing `isProject` leaves the recurring-falls rule to
  resurrect it on the next fall.

The current project shown on Home is an `@AppStorage` string
(`AppPreferences.currentProjectNameKey`), which breaks on rename and does not
sync between devices.

## Goals

A `Project` is a first-class stored entity the user can create, edit, complete,
archive, and delete, with attempt history still owned by sessions.

Non-goals: a Projects tab or screen, search/filter, project photos, sharing,
watchOS project UI, per-attempt beta notes.

## Decisions

| Question | Decision |
|---|---|
| Storage | Standalone `Project` SwiftData model; `SessionProblem` links to it |
| Lifecycle | `active` / `sent` / `archived`, plus hard delete |
| Completion | Logging a flash or send auto-flips an active project to `sent`; reopenable from the editor |
| UI home | The existing `ProjectsSheet`, reached from the Home `CurrentProjectCard` |
| Gym | A `Gym` relationship, not a name string |
| Delete | Removes the `Project` row only; linked `SessionProblem` logs survive |

## Data Model

New file `BoulderTracker/Models/Project.swift`. Every attribute carries a
default and the to-many relationship is optional, matching the CloudKit rules
already documented on `Session`.

```swift
@Model
final class Project {
    var name: String = ""
    var colorGrade: ColorGrade = ColorGrade.unknown
    var status: ProjectStatus = ProjectStatus.active
    var notes: String?
    var createdDate: Date = Date.now
    var isCurrent: Bool = false
    var isSampleData: Bool = false
    var gym: Gym?
    @Relationship(deleteRule: .nullify, inverse: \SessionProblem.project)
    var problems: [SessionProblem]? = []
}
```

New file `BoulderTracker/Models/ProjectStatus.swift`: a `String`-raw `Codable`
enum with cases `active`, `sent`, `archived` and a `displayName`.

`SessionProblem` gains `var project: Project?`.

`Project.self` joins the `Schema` array in `BoulderTrackerApp.makeContainer`.

### Legacy `isProject`

`SessionProblem.isProject` stays in the schema after the backfill, read by
nothing but `ProjectBackfill`. Removing an attribute while other devices still
sync the old CloudKit schema drops their writes, so the attribute is retired in
a later release once the backfill has run everywhere. Its doc comment says so.

## Migration

New file `BoulderTracker/Services/ProjectBackfill.swift`, shaped like
`AchievementCleanup.removeUnearnedOnce`: a `runIfNeeded(context:defaults:)`
guarded by a `UserDefaults` flag that is only set after a successful run, so a
thrown error retries on the next launch. Called from `BoulderTrackerApp.init`
alongside the existing cleanup.

For each group the old `ProjectAggregator.groups(in:)` rule produces:

1. Create a `Project` with the group's name, gym, latest grade, and
   `status = .sent` when any occurrence was sent, otherwise `.active`.
2. Link every `SessionProblem` in the group to it.
3. Set `isProject = false` on those problems.

Projects built purely from sample sessions get `isSampleData = true` so
`SampleDataGenerator.purge` removes them with the rest of the demo data.
`SampleDataGenerator` also deletes sample `Project` rows on purge.

The user's existing `currentProjectName` string, if it matches a created
project, sets that project's `isCurrent`. The preference key is then removed
from `AppPreferences`.

## Aggregator Becomes a Reader

`BoulderTracker/Stats/ProjectAggregator.swift` is replaced by
`BoulderTracker/Stats/ProjectStats.swift`. `ProjectGroup` is deleted; views
`@Query` `Project` directly.

```swift
struct ProjectStats {
    let sessionCount: Int
    let attemptCount: Int
    let lastAttemptDate: Date?
    init(project: Project)
}
```

**Behaviour change:** the "unsent named problem with logged falls is implicitly
a project" heuristic is gone. Projects are explicit from here on. The backfill
preserves every project that heuristic currently surfaces; new ones need the
flag or the add button.

## Current Project

`Project.isCurrent` replaces the `@AppStorage` string. A single writer,
`BoulderTracker/Services/ProjectSelection.swift`, exposes
`makeCurrent(_ project: Project, in context: ModelContext)`, which clears
`isCurrent` on every other project before setting it, so the invariant holds in
one place. Archived and sent projects cannot be made current.

`CurrentProjectCard` shows the `isCurrent` project; when none is set it falls
back to the active project with the most sessions, then the most recent
attempt. That fallback is the tie-break `ProjectAggregator.currentProject`
uses today, moved into `ProjectSelection` as
`current(from projects: [Project]) -> Project?` and rewritten against stored
projects.

## UI

### ProjectsSheet (rewritten)

`@Query` over `Project`, split into Active / Sent / Archived sections, each
sorted by last attempt date descending. Names are user-facing strings with
embedded numbers ("Elektra 2"), so any name sort uses
`localizedStandardCompare`.

- A `+ Add project` row opens the editor with no project.
- Tapping a row opens the editor for that project.
- Trailing control keeps today's shape: a status chip, or a `Set current`
  button on active projects that are not current.
- Empty state text drops the "long-press a problem tile" wording in favour of
  pointing at the add row.

### ProjectEditorSheet (new)

`BoulderTracker/Home/ProjectEditorSheet.swift`, mirroring `ShoeEditorSheet`:
a `nil` project means create. Fields: name (required), gym picker, grade pills,
status, notes. Save and a destructive Delete behind a confirmation that states
attempt history is kept.

### Marking a problem as a project

`ProblemTile`'s context menu and `QuickAddProblemSheet`'s toggle now create and
link a `Project` instead of setting `isProject`. Creation reuses an existing
active project with the same name and gym when one exists, so flagging the same
problem in two sessions does not produce duplicates.

An unnamed quick log cannot become a project — the context-menu item is
disabled when `problem.name` is empty, because a nameless project cannot be
found again.

### Auto-completion

`SessionProblem.recordResult` flips a linked project from `active` to `sent` on
`.flash` or `.send`. This is the single choke point every logging path already
goes through (`ProblemTile`, `QuickLogRow`, watch sync inbox), so no call site
can forget it. The editor reopens a project by setting the status back.

## Testing

Swift Testing cases in `BoulderTrackerTests`:

- Backfill creates one project per derived group, links its problems, clears
  `isProject`, and is a no-op on a second run.
- Backfill marks sample-only projects `isSampleData`.
- `ProjectStats` counts distinct sessions, not problem rows.
- `recordResult(.send)` flips an active linked project to `.sent`; `.fall` does
  not; an archived project is untouched.
- `ProjectSelection.makeCurrent` leaves exactly one project current.
- Archived projects are excluded from the Home card fallback and from
  `Set current`.
- Existing `StatsAggregatorTests` project cases are rewritten against
  `ProjectStats`.

## Build Notes

`project.yml` globs sources by directory, so new files need no manifest edit,
but `xcodegen generate` must run before the new files reach the Xcode target.
