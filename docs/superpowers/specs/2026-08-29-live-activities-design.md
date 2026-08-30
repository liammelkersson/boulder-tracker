# Live Activities — Design

Date: 2026-08-29
Status: Approved, ready for implementation planning

## Goal

Show a running climbing session on the iPhone Lock Screen and in the Dynamic
Island: elapsed time, send count, per-grade tally, and three buttons that log a
send without unlocking the phone.

## Decisions

| Question | Decision |
|---|---|
| Content | Timer, send count, per-grade tally. No heart rate. |
| Interactivity | Quick-log buttons, send-only, three grades. |
| Button grades | The three most-logged grades this session; blue/red/black before anything is logged. |
| Update source | The app, locally. No push. |
| Write path | `LiveActivityIntent`, performed in the app's process. |

Heart rate was rejected: feeding a live BPM to a widget would mean the watch
streaming continuously over WatchConnectivity, at real battery cost on both
devices, for a number that goes stale the moment the watch leaves range.

## Constraint that shapes everything

The signing team is a free personal Apple ID team, which cannot use App
Groups. An extension therefore has no shared container and no shared SwiftData
store, so the usual "extension writes, app reads" pattern is unavailable.

This is survivable because `LiveActivityIntent` runs the intent **in the app's
process**, not the extension's, provided the intent type is compiled into both
targets. The button writes through the app's existing `ModelContainer` with no
shared container involved.

Consequences to hold in mind:

- Live Activity *push* updates need APNs and a paid membership. All updates
  here are local, driven by the app.
- The widget extension needs its own App ID, and inherits the same 7-day
  provisioning expiry as the rest of the project.

Approaches considered and dropped: an App Group with an extension-process
write (unavailable on this team), and having the intent enqueue events for the
app to drain later (pointless — the intent already runs in the app).

## Targets

New target `BoulderTrackerWidgets`:

```
BoulderTrackerWidgets:
  type: app-extension
  platform: iOS
  sources: [BoulderTrackerWidgets, Shared, SharedActivity]
  settings:
    PRODUCT_BUNDLE_IDENTIFIER: com.liammelkersson.BoulderTracker.widgets
    INFOPLIST_KEY_NSExtensionPointIdentifier: com.apple.widgetkit-extension
    TARGETED_DEVICE_FAMILY: "1"
```

Embedded into the iOS app via a `dependencies` entry with `embed: true`,
copied into `$(CONTENTS_FOLDER_PATH)/PlugIns`. The app target gains
`INFOPLIST_KEY_NSSupportsLiveActivities: true`.

## Shared code

New top-level `SharedActivity/`, compiled into the **app and the widget
extension only** — never the watch.

`Shared/` is compiled into the watchOS target, and ActivityKit has no business
there; putting `ActivityAttributes` in `Shared/` would break the watch build.
`SharedActivity/` holds exactly the two things that must exist in two targets:
the activity attributes and the intent.

`SharedActivity/` may import Foundation, ActivityKit, AppIntents, and SwiftUI.
It must not import SwiftData: it is compiled into the extension, which has no
store. The intent reaches the store through a protocol, never the schema.

## Activity state

```swift
struct ClimbingSessionAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let startTime: Date
        let sendCount: Int
        let tally: [GradeTally]
        let quickGrades: [ColorGrade]
        let gradeSystem: GradeSystem
    }
    let sessionSyncID: UUID
    let gymName: String?
}

struct GradeTally: Codable, Hashable {
    let grade: ColorGrade
    let count: Int
}
```

`gradeSystem` travels inside the state deliberately: the extension renders the
labels, and it cannot read the app's `@AppStorage` preference. Without it the
Lock Screen would ignore the user's chosen grade system.

The elapsed time renders with `Text(timerInterval:)`, which ticks on its own.
The Activity is therefore only updated when a log lands, never on a timer.

`staleDate` is set on each update. iOS ends Live Activities after roughly eight
hours; long sessions expire gracefully rather than pretending to be live.

## Presentation

- **Lock Screen:** timer, send count, tally, three quick-log buttons.
- **Dynamic Island compact:** timer.
- **Dynamic Island expanded:** timer, tally, buttons.
- **Minimal:** timer.

## Lifecycle

`SessionActivityPresenter` (app target) wraps `Activity.request`,
`activity.update`, and `activity.end`, guarded by
`ActivityAuthorizationInfo().areActivitiesEnabled`.

Called on session start, after every log, and on session end.

The non-obvious hook: `PhoneSyncCoordinator` refreshes the presenter after
`inbox.apply`. A problem logged on the watch must move the phone's Lock Screen;
without this the Activity goes stale in exactly the scenario the feature exists
for.

The app must behave identically when activities are disabled system-wide. No
code path may depend on an Activity existing.

## The intent

```swift
struct LogSendIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Log a send"
    @Parameter(title: "Grade") var gradeRawValue: Int
    func perform() async throws -> some IntentResult
}
```

App Intents receive no SwiftUI environment, so the intent needs another way to
reach the store. It cannot simply call a SwiftData-backed type: the intent is
compiled into the extension too, and the extension has no store.

So `SharedActivity/` declares a protocol and a registry, both SwiftData-free:

```swift
@MainActor
protocol SessionSendLogging: AnyObject {
    func logSend(grade: ColorGrade)
}

@MainActor
enum SessionSendLog {
    static weak var writer: (any SessionSendLogging)?
}
```

The app target holds the only conformer, `SessionLogWriter`, which owns the
model container and the sync coordinator and registers itself at launch. In the
extension the registry is simply empty, which is correct and harmless — the
intent never performs there.

The registry is a global. App Intents receive no environment, so there is no
alternative; the file says so in a comment rather than hiding it.

`perform()` resolves `SessionSendLog.writer` and calls `logSend(grade:)`, which
applies the send, saves, publishes the sync event to the watch, and refreshes
the Activity — the same sequence as an in-app quick log. A nil writer is a
no-op, not a crash.

## Extraction

`QuickLogRow.log` currently inlines the rule "reuse the unnamed problem for
this grade, else create one". The intent needs the same rule.

Duplicating it would let the Lock Screen and the in-app pills drift into
creating different problems for the same grade in one session. The rule moves
to `QuickLogEntry.problem(for:in:)` and both call it.

## Button selection

`QuickLogGradeSelection.grades(for problems: [SessionProblem]) -> [ColorGrade]`

Top three grades by total log count, ties broken by position in the existing
`ColorGrade.displayOrder`, falling back to `[.blue, .red, .black]` when nothing
has been logged yet. A pure function, so the button-choosing logic is testable
without ActivityKit.

## Testing

In the existing iOS test target:

- `QuickLogGradeSelectionTests` — ordering by count, tie-breaking, fewer than
  three grades present, empty-session fallback.
- `QuickLogEntryTests` — reuses the existing unnamed problem for a grade,
  creates one when absent, and never hijacks a *named* problem.
- `ClimbingSessionStateTests` — the `ContentState` builder: send count, tally
  contents, grade-system passthrough.
- `SessionLogWriterTests` — a send through the writer lands on the session and
  reuses the grade's existing problem, exercising the path the Lock Screen
  button takes.

`SessionActivityPresenter` is not unit tested. ActivityKit does not run under
the test host, so the type is deliberately a thin wrapper with no logic worth
testing. Verified by hand on device.

## Out of scope

Push-updated activities, heart rate on the Lock Screen, logging flashes or
falls from the Lock Screen, starting or ending a session from the Lock Screen,
Apple Watch Smart Stack presentation, and home-screen widgets.
