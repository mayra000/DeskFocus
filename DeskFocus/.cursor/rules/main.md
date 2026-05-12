# DeskFocus iOS — Cursor Rules

## Project Identity
This is **DeskFocus**, an iOS app built in SwiftUI. It combines desk posture tracking (sitting vs. standing) with a Pomodoro timer. There is NO backend, NO server, NO Supabase, NO Firebase. Everything lives on-device. This is a hard constraint — never suggest adding a backend.

## Target
- Platform: iOS 17+
- Language: Swift 5.9+
- UI Framework: SwiftUI (no UIKit unless absolutely necessary)
- Data: SwiftData for logs and tasks, UserDefaults for session/settings state
- Minimum deployment: iOS 17.0

## Architecture

### Store pattern
Use `@Observable` (Swift 5.9 macro, NOT `ObservableObject`). One store per domain:
- `DeskSessionStore` — timer, posture, session state
- `DailyLogStore` — SwiftData reads/writes for posture logs
- `PomodoroStore` — Pomodoro timer + tasks

### File structure — always place files here:
```
DeskFocus/
├── DeskFocusApp.swift
├── ContentView.swift
├── Models/
│   ├── Posture.swift
│   ├── DailyPostureLog.swift     ← @Model
│   └── PomodoroTask.swift        ← @Model
├── Stores/
│   ├── DeskSessionStore.swift
│   ├── PomodoroStore.swift
│   └── DailyLogStore.swift
├── Storage/
│   ├── DeskStorage.swift         ← protocol
│   └── LocalDeskStorage.swift    ← UserDefaults impl
├── Lib/
│   ├── DaySlice.swift
│   ├── WeekHelpers.swift
│   ├── GamificationEngine.swift
│   ├── PostureFill.swift
│   ├── TimeHelpers.swift
│   └── ActivitySummary.swift
├── Notifications/
│   ├── NotificationScheduler.swift
│   ├── SittingHourReminder.swift
│   └── PostureReminderAlerts.swift
├── Views/
│   ├── Desk/
│   │   ├── DeskView.swift
│   │   ├── MainTimerView.swift
│   │   ├── TimerControlsView.swift
│   │   ├── PostureToggleView.swift
│   │   ├── PostureFillView.swift
│   │   ├── StandingGoalView.swift
│   │   ├── StandingWeekBadgesView.swift
│   │   ├── WeeklySummaryView.swift
│   │   ├── ActivityLogView.swift
│   │   └── FactCarouselView.swift
│   └── Pomodoro/
│       ├── PomodoroView.swift
│       ├── PomodoroTimerView.swift
│       └── TaskListView.swift
├── Data/
│   └── Facts.swift
└── Resources/
    ├── Assets.xcassets
    └── Sounds/
```

## Domain Models

### Posture (replaces TypeScript `Posture` type)
```swift
enum Posture: String, Codable { case sitting, standing }
enum SessionDisplayMode: String, Codable { case stopwatch, countdown }
```

### SessionState (replaces `PersistedDeskState` v4)
```swift
struct SessionState: Codable {
    var posture: Posture
    var running: Bool
    var sessionPausedMs: Int
    var runStartedAt: Date?
    var weeklySittingMs: Int
    var weekKey: String
    var factIndex: Int
    var sessionDisplayMode: SessionDisplayMode
    var countdownDurationMs: Int   // always multiple of 5 * 60 * 1000
    var standingGoalMs: Int        // clamped: 5min–8hr, multiple of 5min
    static let `default` = SessionState(...)
}
```

### DailyPostureLog (replaces `Record<string, DailyPostureMs>`)
```swift
@Model class DailyPostureLog {
    var dayKey: String    // "2026-05-12"
    var date: Date
    var sittingMs: Int
    var standingMs: Int
}
```

### PomodoroTask
```swift
@Model class PomodoroTask {
    var id: String
    var title: String
    var done: Bool
    var order: Int
}
```

## Constants (from TypeScript source)
```swift
let POMODORO_MS     = 25 * 60 * 1000
let SHORT_BREAK_MS  =  5 * 60 * 1000
let LONG_BREAK_MS   = 15 * 60 * 1000
let COUNTDOWN_STEP_MS = 5 * 60 * 1000
let DEFAULT_COUNTDOWN_MS = 30 * 60 * 1000
let DEFAULT_STANDING_GOAL_MS = 60 * 60 * 1000
let SITTING_HOUR_MS = 60 * 60 * 1000
let STANDING_CONFETTI_INTERVAL_MS = 30 * 60 * 1000
let DAILY_LOG_KEEP_DAYS = 120
```

## Timer Architecture (critical)

### Reconciliation loop (250ms — mirrors useDeskSession.ts)
```swift
// In DeskSessionStore
Timer.publish(every: 0.25, on: .main, in: .common)
    .autoconnect()
    .sink { [weak self] _ in self?.reconcile(at: Date()) }
```

### Day-boundary splitting (mirrors forEachDaySlice in day.ts)
Every timer tick must split time across midnight boundaries and write to the correct DailyPostureLog row. Never accumulate unbounded time into a single day entry.

### Background handling
iOS kills background timers. Use `UNUserNotificationCenter` to schedule local notifications in advance (e.g. schedule 8 hourly sitting notifications when user starts, cancel unused ones on pause). Do NOT use background tasks for the timer.

### Visibility (mirrors visibilitychange listener)
```swift
.onChange(of: scenePhase) { _, newPhase in
    if newPhase == .active { store.handleForeground() }
}
```

## Storage Rules

### UserDefaults: session state only
```swift
// Key: "desktimer:session"
// Encode/decode SessionState as JSON via JSONEncoder/JSONDecoder
```

### SwiftData: daily logs + Pomodoro tasks
- One `DailyPostureLog` row per calendar day
- Prune entries older than 120 days — once on launch, then once per day
- Never embed the full log dict in UserDefaults (that was the web approach)

### Separation of concerns
- UserDefaults → SessionState, standingGoalMs, activeTaskId, factIndex
- SwiftData → DailyPostureLog[], PomodoroTask[]

## Notifications (replaces browser Notification API)

### Sitting hour reminders
When sitting timer starts, schedule local notifications at each upcoming hour mark. Cancel all when paused or posture switches.
```swift
// Do NOT use background execution. Schedule forward, cancel on pause.
UNUserNotificationCenter.current().add(request) { ... }
UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
```

### Countdown completion
Schedule a single notification at `Date() + remainingMs`. Cancel on pause/clear.

### Permission
Request permission exactly when the user first presses Play — same UX as web version.
```swift
UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { ... }
```

## Gamification / Rings

### WorkweekBadgeDay
```swift
enum WorkweekBadgeKind { case future, complete, partial, missed }
struct WorkweekBadgeDay: Identifiable {
    var id: String { dayKey }
    let labelShort: String   // "M","T","W","TH","F"
    let dayKey: String
    let kind: WorkweekBadgeKind
    let ratio: Double        // 0.0–1.0 for partial fill
}
```

### Standing streak
Walk backward from today through Mon–Fri days only. Weekends are skipped (neither break nor extend the streak). Stop at first workday where standingMs < goalMs.

### GamificationSnapshot
Computed on every 250ms tick from SwiftData log — pure function, no side effects.

## Confetti
Replace `canvas-confetti` with `CAEmitterLayer` particle system. Fire on:
- Every completed Pomodoro
- Every 30 minutes of continuous standing

## Export
Replace SheetJS with `UIActivityViewController`. Offer JSON export (easy) and optionally CSV (simple, no dependencies). No xlsx on native unless user specifically requests it — suggest a Swift package like `CoreXLSX` only if asked.

## Wellness Facts
Static Swift array in `Facts.swift`. Same data as the web app's `facts.ts`. Auto-advance every 30 seconds using a Timer. Manual prev/next via buttons.

## SwiftUI Patterns to Follow

### State injection — environment objects
```swift
// In DeskFocusApp.swift
@State private var deskStore = DeskSessionStore(...)
ContentView()
    .environment(deskStore)
    .environment(pomodoroStore)
```

### Reading in views
```swift
@Environment(DeskSessionStore.self) private var deskStore
```

### SwiftData queries in views
```swift
@Query(filter: #Predicate<DailyPostureLog> { $0.date >= sevenDaysAgo },
       sort: \.date, order: .reverse)
var recentLogs: [DailyPostureLog]
```

## Code Style
- Prefer `@Observable` over `ObservableObject` + `@Published`
- Prefer `async/await` over completion handlers
- No force-unwrap (`!`) except in previews
- All store methods `@MainActor`
- Free functions for pure logic (gamification, day slicing, week helpers)
- No third-party dependencies unless explicitly discussed — the goal is zero external packages

## What NOT to do
- Do NOT add any server, API calls, or network requests
- Do NOT use UIKit views unless SwiftUI cannot do it
- Do NOT use Combine for anything except Timer publishers (use @Observable instead)
- Do NOT store the full DailyLog dict in UserDefaults
- Do NOT run background timers — use local notifications instead
- Do NOT use `ObservableObject` or `@Published` — use `@Observable`
- Do NOT install third-party packages without asking
- Do NOT suggest Supabase, Firebase, CloudKit, or any sync service
