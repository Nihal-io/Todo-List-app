# Todo Matrix

A local-first Flutter app that pairs an **Eisenhower priority grid** with a **habit tracker**. Plan with urgency and importance, then watch your recurring routines compound into streaks and completion analytics — all on-device, no account, no cloud, no telemetry.

Built for people who want a real productivity surface without handing their day over to a SaaS dashboard.

## Why

Most todo apps either treat every task as a flat checkbox or lean entirely on calendar-style scheduling. Most habit trackers don't help you triage what's urgent versus important right now. Todo Matrix sits in the middle:

- **Capture** what you have to do.
- **Triage** it across the Eisenhower quadrants — Do, Schedule, Delegate, Eliminate.
- **Repeat** the routines that matter as recurring tasks.
- **See** how consistent you've actually been on the analytics screen.

And because everything is stored locally, your task history is yours — period.

## Features

### Home
- Today and Upcoming tabs with a today-progress card and an optional overdue panel
- Auto-sorting that keeps the list stable while you complete things, so tasks don't shuffle out from under your finger
- Inline expandable subtasks with gated parent completion (parent only ticks when every subtask is done)
- One-line notes preview on each row so important context is visible without opening the sheet
- Bulk selection for multi-task complete / delete / quadrant moves
- Live filtering by quadrant, priority, or free text (title, notes, subtasks)
- Streak badges on recurring tasks

### Grid view (Eisenhower matrix)
- Four-quadrant layout: Do First, Schedule, Delegate, Eliminate
- Auto-sorted by urgency within each quadrant, with overdue highlighting and date badges
- **Long-press and drag** any tile to move it to another quadrant
- **Edit mode** (via the overflow menu) flips single-tap from "complete" to "open detail sheet" without losing drag-to-quadrant
- Tile colors are configurable per quadrant

### Calendar
- Month view with a day panel showing everything active for the selected date
- Supports simple tasks, multi-day spans, events, and weekly-recurring rules
- Same gestures as Home: tap a checkbox to complete, tap a row to open subtasks, long-press for the detail sheet

### Recurring tasks & habit tracking
- Weekly recurrence (any combination of weekdays, optional "until" date)
- Per-day completion tracking — your Monday tick and your Wednesday tick are separate
- **Early completion supported**: ticking next Monday's task today snaps the credit to Monday and your streak updates immediately
- Streaks count both past and future completed occurrences

### Analytics (Settings → Insights)
- 21-day overall completion bar chart, **subtask-weighted**: if today's recurring task with two subtasks is half-done, today's bar reads 50% for that task — not 0%
- Per-day percentage reflects the average across every recurring task that applies on that day, so two tasks where you completed one is a 50% bar, not a missed day
- Per-task streak rows: current streak vs. best streak, repeat pattern, fire/trophy chips
- "Stay tuned" roadmap card for upcoming insights

### Reminders
- Local notifications for scheduled tasks and events (Android)
- Optional persistent "today's tasks" foreground notification
- Permission flow that handles Android 13+ `POST_NOTIFICATIONS` and Android 12+ exact-alarm grants gracefully

### General
- Material 3 throughout, with light, dark, and system theme modes
- Configurable color palettes, density, and text scale
- Compact, themed snackbars with undo on completion
- Adaptive launcher icon

## Privacy

Everything lives on your device. There is no account, no login, no sync server, no analytics SDK, no crash reporter. The only network surface in the app is whatever Android itself does to deliver notifications — and even those are scheduled locally.

If you uninstall the app, your data is gone. If you back it up via Android's normal app-data backup, it goes wherever you've configured your phone to back up to.

## Roadmap

The app is intentionally still small. Planned for the analytics surface:

- Monthly analytics rollups
- All-task analytics (one-offs and events, not just recurring)
- Pearson correlation between habits ("I read more on days I exercise")
- AI-generated plain-English insights about your patterns

## Getting started

Requires [Flutter](https://docs.flutter.dev/get-started/install) **3.24+** and Dart **3.5+**.

```bash
flutter pub get
flutter run                                 # debug, on the device of your choice
flutter test                                # run the test suite
```

### Building a release

For sideloading (e.g. distributing the APK via GitHub Releases):

```bash
flutter build apk --release
```

For Play Store upload:

```bash
flutter build appbundle --release
```

Release builds are signed if `android/key.properties` exists. The file is gitignored — create your own with:

```properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=/absolute/path/to/upload-keystore.jks
```

If `key.properties` is absent the build still produces an unsigned bundle/APK.

## Platform support

| Platform | Status |
|---|---|
| Android | Primary target — fully supported |
| iOS / macOS / Linux / Windows / Web | Flutter scaffolding present, not actively tested. Local notifications are Android-only. |

## Tech stack

- **Flutter 3.24+ / Dart 3.5+**
- **Riverpod** for state
- **go_router** for navigation
- **shared_preferences** + JSON serialization via `path_provider` for storage
- **flutter_local_notifications** + `timezone` for reminders
- **table_calendar** for the calendar widget

No backend, no third-party services.

## Contributing

Issues and PRs welcome. Before sending a PR:

```bash
flutter analyze       # must report no issues
flutter test          # must pass
```

Keep commits scoped and message them in the imperative.

## License

MIT — see [LICENSE](LICENSE).
