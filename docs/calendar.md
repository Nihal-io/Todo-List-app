# Calendar Panel — Conversation Notes

This document captures the design and implementation discussion for the calendar feature in the personal todo list app.

## Project Context

The app is a personal todo list built with Flutter. It differs from typical todo apps in a few ways:

- Tasks live on an **Eisenhower matrix** (each task is a node on that graph)
- A **calendar** shows when tasks are due
- Two task types are planned:
  - **Events** — span multiple days (exams, hackathons, etc.)
  - **Normal tasks** — single due date
- **Modularity** is a goal so notifications and an experimental cowork feature can be added later
- **Cowork** is deferred for now

Tech stack already in place: Flutter, Riverpod, Drift, go_router, table_calendar, uuid, intl.

## UI Style Decisions

| Decision | Choice |
|----------|--------|
| Visual vibe | Light, clean — crisp whites, soft shadows, airy feel (Things 3 / Apple Reminders style) |
| Navigation | Bottom nav with center FAB |
| Nav structure | `Today \| Matrix \| [+ FAB] \| Calendar \| Settings` |
| Matrix (initial) | Empty placeholder panel — build step by step, UI first |

The Eisenhower matrix panel was intentionally left as a placeholder until the calendar and other UI pieces were in place.

## UI Scaffold (Completed Before Calendar)

Before the calendar work, the app shell was built:

```
lib/
  main.dart
  app.dart
  theme/app_theme.dart
  routing/router.dart
  shared/widgets/shell_scaffold.dart
  features/
    today/today_screen.dart
    matrix/matrix_screen.dart
    calendar/calendar_screen.dart
    settings/settings_screen.dart
```

- Material 3 light theme, indigo seed color (`#5C6BC0`)
- Background `#F8F9FA`, white cards with soft borders
- `StatefulShellRoute.indexedStack` for tab navigation
- `BottomAppBar` with `CircularNotchedRectangle` and center FAB for adding tasks
- Active tab indicator: small colored underline under the icon

## Calendar Panel Request

**Goal:** Build a normal calendar first, similar to a Samsung calendar app — before wiring in task data or multi-day events.

**Approach:** Use the existing `table_calendar` dependency from `pubspec.yaml`. No database or task model yet; UI only.

## Calendar Implementation

**File:** `lib/features/calendar/calendar_screen.dart`

### Layout

1. **Month grid (top)** — white card, full month view
   - Chevron arrows for month navigation
   - Centered month/year title
   - Sunday as first day of week
   - Outside days hidden for a clean look
   - Today: soft indigo circle background
   - Selected day: solid indigo filled circle, white text
   - Dot markers under dates (up to 3) — ready for future task indicators

2. **Day header (middle)** — label for the selected date
   - Shows "Today" or "Tomorrow" when applicable
   - Otherwise: e.g. `Wednesday, May 28`

3. **Day content (bottom)** — empty state for now
   - Icon + "No tasks for this day"
   - Will be replaced with the task list once the data model exists

### Styling

Matches the app theme: light background, indigo primary, muted grey for weekday labels and empty state text.

### State

Local `StatefulWidget` state only:

- `_focusedDay` — month being viewed
- `_selectedDay` — tapped/selected date

No Riverpod or Drift integration yet.

## Calendar Design Discussion — Spanning Bars

After the basic calendar shell was in place, the next discussion centered on how to show multi-day events (exams, hackathons, gym week) alongside single-day tasks (assignments).

Three options were considered:

- **Option A — Spanning event bars on the month grid.** Colored bars stretch across the days an event covers; single-day tasks shown as dots.
- **Option B — Dot clusters on the grid + a rich day panel.** Easier to implement on top of `table_calendar` but loses at-a-glance event durations.
- **Option C — Scrollable week strip + event bands + agenda.** Clean on mobile but loses the month overview.

**Decision: Option A.**

### Spanning Bars without Replacing `table_calendar`

Key insight: `table_calendar` supports full per-cell overrides via `calendarBuilders`. By rendering a short colored `Container` inside each cell and setting `cellMargin` to have zero horizontal gap, adjacent same-color cells visually merge into a continuous bar.

Per-cell bar segment:

- Left-rounded cap on the event's start day **or** the leftmost column (Sunday)
- Right-rounded cap on the event's end day **or** the rightmost column (Saturday)
- Flat (no caps) on middle days

This is the same week-wrap behavior Google Calendar uses on mobile. `rowHeight` was bumped from 44 to 64 to fit the date number + up to 3 stacked bars + single-day task dots.

## Data Model Discussion

Initial design used two separate types: `CalendarEvent` (with span) and `Task` (single due date). After reflection the user observed that an event is essentially a task that isn't fixed to a single day. The model was unified.

**Final model — single `Task` type:**

```dart
enum TaskCategory { exam, hackathon, gym, study, work, other }
enum TaskPriority { low, medium, high }

class Task {
  final String       id;
  final String       title;
  final DateTime     startDate;
  final DateTime?    endDate;   // null = single-day
  final bool         completed;
  final TaskPriority priority;
  final TaskCategory category;

  bool get isMultiDay => endDate != null;
  Color get color     => category.color;
  bool occursOn(DateTime day) { ... }
  bool isStartDay(DateTime day) { ... }
  bool isEndDay(DateTime day)   { ... }
}
```

- Color comes from the **category** (each category has a fixed color)
- **Priority** applies to all tasks, both single-day and multi-day
- Multi-day tasks can be checked off the same way single-day tasks can
- `TaskCategory.study` and `TaskCategory.work` were added so single-day tasks have meaningful default categories too

## Files Created / Changed

### Data layer

- `lib/models/task.dart` — unified `Task` model with `TaskCategory` and `TaskPriority`
- `lib/providers/tasks_provider.dart` — `StateNotifier<List<Task>>` with `add`, `remove`, `toggle`, `update`. `tasksForDayProvider.family<List<Task>, DateTime>` filters via `Task.occursOn(day)` so multi-day tasks appear on every day they span. Ships with sample data covering both kinds.
- `lib/providers/selected_day_provider.dart` — `StateProvider<DateTime>` for the calendar's currently selected day. Used by the calendar (read/write) and shared with the global Add sheet to pre-fill its start-date (see [`add_task.md`](add_task.md)).

### Calendar UI

- `lib/features/calendar/calendar_screen.dart` — full rewrite:
  - `ConsumerStatefulWidget` reading from the unified providers
  - Custom `_DayCell` builder: date number circle, up to 3 stacked `_BarSegment` bars (multi-day tasks), then a row of small colored dots for single-day tasks (each dot colored by its task's category)
  - `_BarSegment` handles start/end caps and week-wrap caps
  - `_DayPanel` is a single flat scrollable list; tasks are sorted multi-day-first then by priority. Each row uses `_TaskTile` with a colored left border (category color), checkbox, title, category label, optional date range, and a priority badge
  - Tap a task tile in the day panel to toggle completion (strikethrough)

### Removed

- `lib/models/calendar_event.dart`
- `lib/providers/calendar_events_provider.dart`

## Related: Add Task Flow

Creating tasks happens through the global FAB and bottom sheet, which is an app-wide feature rather than a calendar feature. See [`add_task.md`](add_task.md) for that flow.

## Visual Result

```
[ May 2026                      < > ]
[ Su   Mo   Tu   We   Th   Fr   Sa ]
[  1    2    3    4    5    6    7  ]
[       ╔══════════════════╗        ]   ← Exams (high, red)
[  8    9   10   11   12   13   14  ]
[            ╔═════════╗             ]   ← Hackathon (medium, blue)
[            ●          ●            ]   ← single-day task dots
─────────────────────────────────────
Today
─────────────────────────────────────
  ▌ Exams              Exam · MAY 4–6   [HIGH]
  ▌ Submit assignment  Study           [HIGH]
  ▌ Read chapter 4     Study           [MED]  ✓
```

## What's Next (Not Done)

- Persist tasks via Drift (currently in-memory sample data)
- Today tab — list of tasks due today
- Matrix tab — Eisenhower matrix with tasks as nodes
- Notifications integration
- Cowork (deferred)

## Git / Repo Notes

The user initialized the git repository themselves. Project convention: do not create or modify `.gitignore` or `README.md` as part of agent work unless explicitly requested.
