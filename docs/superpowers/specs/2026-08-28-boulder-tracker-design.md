# Boulder Tracker — Design Spec

**Date:** 2026-08-28
**Status:** Approved design, pending implementation plan
**Audience:** Single user (Liam), personal device, iOS 26+
**Stack:** SwiftUI + SwiftData, no third-party packages, Liquid Glass design language

## 1. Purpose

Personal bouldering tracker for logging gym sessions, tracking progression through
Klättervigören Jönköping's color grade system, and staying motivated via stats,
achievements, and a technique roadmap.

## 2. Scope

### In scope (v1)

- Live session logging (timer + quick-add problems at the gym) and retroactive
  session entry.
- Per-problem logging: color grade, route styles (multi-select), attempt count,
  result (flash / send / project), optional photo, notes.
- Gym and climbing-partner selection per session.
- Home overview (recent activity snapshot + highlight card).
- Calendar view of sessions with day detail.
- Stats page with charts and personal bests.
- Manual-checkbox progression roadmap (6 levels, static content).
- Achievements (~20, auto-unlocked on session save).
- HealthKit: write climbing workouts on session save.

### Out of scope (v1)

- Strava integration (designed-for; see Future Ideas).
- iCloud/CloudKit sync — local storage only.
- Social features, accounts, backend.
- Apple Watch app (see Future Ideas).

## 3. Grade system

Fixed enum `ColorGrade`, ordered easiest → hardest. Klättervigören Jönköping scale:

| Color | French | V-grade |
|-------|--------|---------|
| 🟢 Green | 4–5b | V0–V1 |
| 🔵 Blue | 5b–6a | V1–V3 |
| 🔴 Red | 6a–6c | V3–V5 |
| ⚫ Black | 6c–7a | V5–V7 |
| ⚪ White | 7b–7c | V8–V10 |
| 🟡 Yellow | 8a+ | V11+ |

French/V-grade ranges are display metadata on the enum. All logic compares enum
order, never raw strings.

## 4. Data model (SwiftData)

```
Session
  date: Date
  startTime: Date
  endTime: Date?            // nil while session live
  notes: String?
  healthKitWorkoutID: UUID? // for delete propagation
  gym: Gym?
  partners: [Partner]
  attempts: [ProblemAttempt]  // cascade delete

ProblemAttempt              // one boulder problem within one session
  colorGrade: ColorGrade
  styles: [RouteStyle]      // multi-select
  attemptCount: Int
  result: AttemptResult
  photoFilename: String?    // file in Documents/RoutePhotos/, not in DB
  notes: String?

Gym
  name: String
  isDefault: Bool           // Klättervigören Jönköping seeded on first launch

Partner
  name: String

RoadmapProgress
  itemID: String            // stable ID from static roadmap content
  checkedAt: Date

Achievement
  id: String                // matches definition in code
  unlockedAt: Date
```

### Enums

- `ColorGrade`: green, blue, red, black, white, yellow — with display color,
  French range, V range.
- `RouteStyle`: dyno, sloper, crimp, jug, pinch, pocket, overhang, slab,
  vertical, roof, compression, coordination, mantle, arete, traverse.
  Fixed list in v1.
- `AttemptResult`: flash (topped first try), send (topped after >1 attempt),
  project (not topped yet; attemptCount still recorded).

### Photos

JPEG files in `Documents/RoutePhotos/`, filename referenced from
`ProblemAttempt`. Thumbnails cached. Deleting an attempt deletes its photo file.

### Sessions are independent

A project attempted across multiple sessions is logged as separate
`ProblemAttempt` rows per session. No cross-session problem identity in v1
(revisit if route discontinuation lands — see Future Ideas).

## 5. Screens (5 tabs)

### Tab 1 — Home

Default state:
- Greeting header: name + "X climbing days in last 3 months".
- Large card: total climb time for period (stopwatch/gauge motif).
- Metric row: problems sent / attempts / completion rate.
- Highlight card ("proudest send"): recent hardest problem with most attempts —
  gym, color, attempt count, photo thumbnails.
- Primary action: **Start Session** (glass button) with gym + partner pickers.
- Secondary: **Add Past Session** (retro form: manual date, duration, same
  problem entry UI).
- Recent sessions list.

Live state (replaces overview while session running):
- Timer header, running tally per color.
- Quick-add sheet: tap color → style tags → attempt stepper → result →
  optional camera photo. Big touch targets; minimum path 3 taps.
- End session → summary card (duration, problems, sends, flash rate) → save +
  HealthKit write → restore overview.

Overview aggregation uses the same `StatsAggregator` as the Stats tab,
defaulting to a 3-month window.

### Tab 2 — Calendar

- Month grid; dot per session day, dot color = hardest grade sent that day.
- Tap day → `SessionDetailView`: problem list with photos, partners, gym,
  session stats.

### Tab 3 — Stats

- Period picker: month / 3 months / year / all.
- Summary cards: sessions, total time, problems, sends, flash rate.
- Charts (Swift Charts):
  - Sends per grade over time (progression).
  - Grade distribution.
  - Style breakdown (spot weaknesses).
  - Weekly volume.
- Personal bests: hardest flash, hardest send, longest streak.

### Tab 4 — Roadmap

- Six colored level sections (Green → Yellow) from static structured content.
- Manual checkboxes for every skill/milestone; checks persist as
  `RoadmapProgress` rows.
- Progress ring per level. Current level = first level with unchecked items
  after fully-checked predecessors.

Roadmap content (verbatim source): Green "Learn to Climb", Blue "Build
Technique", Red "Intermediate Climber", Black "Advanced", White "Very
Advanced", Yellow "Elite" — each with goal, focus/learn list, training list,
milestones as provided by the user.

### Tab 5 — Profile

- Achievements grid (locked greyed, unlocked with date).
- Gym management (add/rename), partner management (add/rename).
- HealthKit permission toggle.
- Export data as JSON.
- About.

`SessionDetailView` reachable from Calendar and from Home's recent list.

### Liquid Glass

- Native `TabView` floating glass tab bar.
- `.glassEffect()` on stat cards and live-timer overlay.
- Glass toolbars; tinted glass buttons using grade colors.
- System dark mode support.

## 6. HealthKit

- Write-only in v1: on session save, create `HKWorkout` activity type
  `.climbing` with start/end time. Retro sessions written too.
- Store workout UUID on `Session`; deleting a session deletes its workout.
- No read permissions requested.
- Strava path later: Strava app reads Health workouts, or direct OAuth upload
  in v2 — session model already maps 1:1 to an activity.

## 7. Achievements

Definitions live in code (`AchievementEngine`); DB stores only unlocks.
Checked after every session save. Unlock shows a banner and persists date.

- **Firsts:** first session; first send per color (×6); first flash; first
  photo; first partner session.
- **Volume:** 10 / 50 / 100 / 500 problems sent; 10 / 50 / 100 sessions.
- **Streaks:** 3 sessions/week for 4 consecutive weeks; a session every week
  for 5 weeks running.
- **Skill:** flash 10 blues; send problems in 5+ styles; 100 attempts on
  projects.
- **Fun:** Night Owl (session ends after 21:00); Marathon (2h+ session);
  Globetrotter (3+ distinct gyms).

## 8. Project structure

One type per file. Feature folders:

```
BoulderTracker/
  App/            BoulderTrackerApp, RootTabView
  Models/         Session, ProblemAttempt, Gym, Partner,
                  RoadmapProgress, Achievement,
                  ColorGrade, RouteStyle, AttemptResult
  Home/           HomeView, OverviewSection, LiveSessionView,
                  QuickAddProblemSheet, SessionSummaryView, RetroSessionForm
  Calendar/       CalendarView, SessionDetailView
  Stats/          StatsView, chart subviews, StatsAggregator
  Roadmap/        RoadmapView, RoadmapLevelSection, RoadmapContent
  Profile/        ProfileView, AchievementsGrid, GymListView, PartnerListView
  Services/       HealthKitWriter, PhotoStore, AchievementEngine
```

Views stay dumb. `StatsAggregator`, `AchievementEngine`, `PhotoStore` are pure
logic, injectable, no UI imports. `HealthKitWriter` sits behind a protocol so
tests use a fake.

## 9. Error handling

- Photo save failure: attempt still saves without photo; user informed inline.
- HealthKit permission denied or write failure: session still saves locally;
  non-blocking notice. Workout writes are best-effort, never block logging.
- SwiftData save failures surface as alerts; live session state kept in memory
  until save succeeds.
- App killed mid-session: live session persists (startTime saved on start,
  endTime nil); on relaunch offer resume or end.

## 10. Testing

Swift Testing framework, TDD for logic:

- `StatsAggregator`: flash rate, streaks, grade progression, style breakdown,
  period windows.
- `AchievementEngine`: every unlock rule, including streak edge cases.
- `PhotoStore`: save/load/delete round-trip.
- Models: round-trip in in-memory SwiftData container.
- `HealthKitWriter`: protocol-faked; no real HealthKit in tests.
- UI verified manually on simulator + device. No UI test suite in v1.

## 11. Build & capabilities

- Xcode project, iOS 26 minimum target, iPhone only.
- No third-party dependencies.
- Capabilities/entitlements: HealthKit; camera + photo library usage
  descriptions.

## 12. Future ideas (explicitly not v1)

- **Apple Watch app** — start/stop session and quick-add problems from the
  wrist; heart rate into session stats.
- **Strava integration** — direct OAuth upload of sessions as activities.
- **Shoe logging** — track shoe pairs per session, mileage/wear, resole
  reminders.
- **Route discontinuation** — gyms reset walls; mark routes/problems as
  discontinued so stale projects close out. Requires cross-session problem
  identity (named problems per gym), which sessions-are-independent v1
  deliberately skips.
- **Skill net (radar/pizza chart)** — smarterscout-style circular chart of
  climbing profile: performance per route style (flash rate / send rate per
  style bucket), grouped like attacking/defensive/possession into e.g.
  power / technique / endurance. Data already captured via `RouteStyle` +
  results, so this is a Stats-tab addition.
- **iCloud sync** — SwiftData + CloudKit migration path kept open (local-only
  chosen for v1).
- **Custom route styles** — user-defined styles beyond the fixed enum.
