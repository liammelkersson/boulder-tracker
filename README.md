# Boulder Tracker

<img src="https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExcG40NWQzcHJtemh5c3R2MG04YmVoamhycXkxbHpqazVxZnJ0ZTFqdCZlcD12MV9naWZzX3NlYXJjaCZjdD1n/5nqwsSMu5mKeieCaJ5/giphy.gif" alt="Bouldering" width="320" />

Personal bouldering tracker for iOS and watchOS. Log gym sessions live or after the
fact, track progression through a colour-based grade scale, and stay motivated with
stats and achievements.

SwiftUI + SwiftData, no third-party packages.

## Features

- **Live sessions** — start a timer at the gym and quick-add problems as you send
  them, or enter a session retroactively.
- **Per-problem logging** — colour grade, route styles, movement-skill tags,
  attempt count, result (flash / send / project), optional photo, notes. Logged
  problems can be edited afterwards from the tile's context menu.
- **Projects** — track unsent problems across sessions until they go, with their
  own route styles inherited when a problem is promoted.
- **Calendar & stats** — month grid of sessions, charts, personal bests, a grade
  pyramid over distinct sends, and a per-session flash goal.
- **Variety coverage** — wall-angle, hold-type, and movement-skill coverage over a
  period, naming what you haven't touched ("go find a roof").
- **Achievements** — ~20 achievements, unlocked automatically on session save.
- **Apple Watch app** — start and log a session from the wrist, with heart rate and
  active energy from a live `HKWorkoutSession`, synced back to the phone.
- **Live Activity** — session timer and quick-log actions on the Lock Screen and in
  the Dynamic Island.
- **HealthKit** — each saved session is written as a climbing workout.

## Grade system

Grades are stored as a `ColorGrade` enum (Klättervigören Jönköping scale, ordered
easiest → hardest). How that grade is *numbered* in the UI is a display preference —
Font or V-scale — and switching never migrates or reinterprets stored data. The hold
colour is always shown as a swatch next to the number.

| Colour | Font | V-scale |
|--------|------|---------|
| 🟡 Yellow | <4 | – (warm-up) |
| 🟢 Green | 4–5 | V0–V2 |
| 🔵 Blue | 5+–6A | V3–V4 |
| 🔴 Red | 6B–6C | V5–V6 |
| ⚫ Black | 7A–7B | V7–V8 |
| ⚪ White | 7C+ | V9+ |

## Requirements

- Xcode 26 or later (iOS 26 / watchOS 26 deployment targets, Swift 6)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`

## Getting started

```sh
xcodegen generate
open BoulderTracker.xcodeproj
```

`project.yml` is the source of truth for the project structure. **Run
`xcodegen generate` after adding, moving, or deleting any source file** — a stale
project produces confusing "no member" compile errors rather than a missing-file
error.

## Targets

| Target | Platform | Purpose |
|--------|----------|---------|
| `BoulderTracker` | iOS | Main app |
| `BoulderTrackerWidgets` | iOS | Live Activity widget extension |
| `BoulderTrackerWatch` | watchOS | Watch companion app |
| `BoulderTrackerTests` | iOS | Unit tests (Swift Testing) |
| `BoulderTrackerUITests` | iOS | UI tests |
| `BoulderTrackerWatchTests` | watchOS | Watch unit tests |

## Tests

```sh
# iOS
xcodebuild test -scheme BoulderTracker \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# watchOS
xcodebuild test -scheme BoulderTrackerWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)'
```

With `-quiet`, `xcodebuild` prints a spurious `command failed with exit code 0` line;
grep the output for `Test run with` or `BUILD SUCCEEDED` instead of trusting that.

## Layout

```
BoulderTracker/          iOS app
  App/                   Entry point, root navigation, theme
  Design/                Reusable SwiftUI components
  Home/                  Session logging (live + retro), problem forms
  Activities/            Calendar view
  Stats/                 Charts and personal bests
  Profile/               Preferences, gyms, partners, shoes
  Onboarding/            First-run flow
  Models/                SwiftData models
  Services/              Achievements, HealthKit, sync, photos, persistence
BoulderTrackerWatch/     watchOS companion + HKWorkoutSession
BoulderTrackerWidgets/   Live Activity widget extension
Shared/                  Types shared by phone and watch (grades, styles, sync)
SharedActivity/          Live Activity attributes and App Intents
docs/                    Design specs, implementation plans, notes
```

## Storage and sync

Data is local SwiftData. `BoulderTrackerApp.makeContainer()` attempts a CloudKit-backed
container and falls back to a local store when that throws.

CloudKit is currently **off**: the iCloud keys are commented out of
`BoulderTracker.entitlements` because the signing team is a free Apple Developer
account, and Apple refuses the iCloud capability there. Re-enabling needs a paid
Developer Program membership plus the two entitlement keys restored — see
[`docs/cloudkit-backup.md`](docs/cloudkit-backup.md).

The CloudKit-compatible schema constraints still apply to the models: no
`@Attribute(.unique)`, every relationship needs an explicit inverse, and to-many
relationships must be optional.

## Docs

Design specs and implementation plans live in `docs/superpowers/`.
