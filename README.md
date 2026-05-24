# Todo Matrix

A local-first todo app built with Flutter. Tasks live on your device — no account, no cloud sync.

Organize work with an Eisenhower grid, stay on top of today from Home, plan on the Calendar, and track recurring habits with streaks and analytics.

## Features

### Home
- **Today & Upcoming** — separate lists with a progress card for today’s actionable tasks
- **Overdue panel** — past-deadline tasks surfaced at the top (optional)
- **Smart sorting** — tasks auto-sort by quadrant and urgency; completing a task keeps it in place until you leave and return
- **Multi-step tasks** — tap the row to expand subtasks inline; tap the checkbox to complete all at once; parent completes only when every subtask is done
- **Bulk select** — move, complete, or delete multiple tasks at once
- **Search & filters** — filter by quadrant, priority, or text (title, notes, subtasks)
- **Streak badges** — recurring tasks show a flame icon with the current streak count

### Grid View (Eisenhower matrix)
- Four quadrants: **Do First**, **Schedule**, **Delegate**, **Eliminate**
- **Auto-sorted by urgency** within each quadrant, with overdue highlighting and date badges
- **Long-press & drag** a task to move it to another quadrant
- **Edit mode** — tap the ⋮ menu to open tasks for editing without leaving the grid
- Completed items stay visible (crossed off) until you revisit the tab

### Calendar
- Month calendar with a **day panel** listing everything active that day
- Supports **tasks, events, multi-day items, and recurring schedules**
- Same row interactions as Home: tap to complete or expand subtasks, long-press for overview

### Task types
- **Simple tasks** — one-off items with optional deadline
- **Multi-step tasks** — checklist of subtasks with gated parent completion
- **Recurring tasks** — repeat on selected weekdays; completion tracked per day
- **Events** — calendar entries with optional auto-complete when they end

### Analytics
- **Recurring task analytics** — 21-day completion chart and per-task streak breakdown
- Reach it from **Settings → Recurring task analytics**
- Shows current streak, best streak, and completion rate for each recurring habit

### Reminders & notifications
- Scheduled reminders for tasks and events (Android)
- Persistent “today” notification option
- Permission prompts when notifications are blocked

### Settings
- Density, date format, quadrant colors, and grid display options
- Toggle progress card, overdue panel, axis labels, and urgency badges
- **Stay tuned** roadmap for upcoming features (monthly analytics, AI insights, and more)

### General
- **Compact snackbars** — undo on complete, feedback on create/delete/blocked actions
- **Offline** — all data stored locally on device
- **Task overview sheet** — long-press a task on Home or Calendar for details, notes, and subtasks

## Getting started

Requires [Flutter](https://docs.flutter.dev/get-started/install) 3.24+.

```bash
flutter pub get
flutter run
flutter build apk --release   # Android release APK
```

## License

MIT — see [LICENSE](LICENSE).
