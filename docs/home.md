# Home Screen — Conversation Notes

## List behavior (Current / Upcoming / Overdue)

### Current task
Shows every **task** active today (not events). Completed items **stay in the list** with a green check and strikethrough; incomplete items sort above completed ones.

Recurring tasks (e.g. Gym on Mon/Wed/Fri) appear here on matching weekdays. Ticking uses per-day completion (`toggleForDay`).

### Upcoming task
Shows items with a **future** date relative to today:

| Type | Appears when |
|------|----------------|
| Single-day task | `startDate` is after today |
| Multi-day task | `startDate` is after today (same rule — if it already started, it lives under Current, not Upcoming) |
| Recurring task | Next matching weekday after today exists (within `until` if set). Label: `Next: May 28` |
| Event | `startDate` is after today; not manually completed |

Recurring tasks were previously excluded entirely from Upcoming; they now show with their next occurrence date.

### Overdue
Only non-recurring **tasks** past their deadline and not completed. Events and recurring tasks never appear here. Ticking an overdue task removes it from this panel (it moves to Current as completed).

## Events vs tasks

- **Event** — optional checkbox (can tick off manually). Never overdue. Auto-completes visually once `endDate` passes. Still excluded from Current/Upcoming task tabs (calendar only for ambient context).
- **Task** — checkbox required for completion tracking; can go overdue.
