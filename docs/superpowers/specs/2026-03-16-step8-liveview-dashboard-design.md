# Step 8: LiveView Dashboard with PubSub

## Overview

Single-page LiveView dashboard for real-time hydration tracking. Absorbs the
original Step 9 (PubSub integration) since a LiveView without reactivity
defeats the purpose.

**Route:** `/dashboard` (browser pipeline)
**User:** Hardcoded John Doe from seeds (until Step 10/auth)
**i18n:** All strings via `gettext`, default locale `en`

## Architecture: 3 Layers

### Layer 1 — Contexts (Business Logic)

Pure business logic. No knowledge of LiveView. Contexts broadcast PubSub
events after successful mutations so that any caller (LiveView, REST, Oban)
triggers real-time updates.

**HydrationTracking — new functions:**

```elixir
daily_progress(user_id, date, goal_ml)
# => %{total_ml: 1500, goal_ml: 2000, percentage: 75.0, intake_count: 6}

list_daily_intakes(user_id, date)
# => [%WaterIntake{}, ...]   (no pagination, simple list, ordered by time desc)

weekly_summary(user_id, date, goal_ml)
# => [%{date: ~D[2026-03-10], total_ml: 1800, goal_ml: 2000}, ...]
```

**UserManagement — no changes:**
- `get_user/1` and `get_alarm_settings_by_user/1` already exist.

**Cross-context boundary:** The LiveView fetches `goal_ml` from
`UserManagement.get_alarm_settings_by_user/1` and passes it as an argument to
HydrationTracking functions. HydrationTracking never queries UserManagement
directly.

### Layer 2 — Live Components (State + Orchestration)

Stateful components that manage their own assigns, subscribe to PubSub, call
contexts on events, and delegate rendering to function components.

```
DashboardLive              — mount, layout grid, subscribe to "user:#{id}"
ProgressComponent          — daily progress (consumption vs goal)
HistoryComponent           — list of today's intakes with delete
IntakeFormComponent        — form to log water intake
WeeklySummaryComponent     — last 7 days summary
NextAlarmComponent         — next alarm info
AlarmSettingsComponent     — view/edit alarm settings (modal)
```

### Layer 3 — Function Components (Pure UI)

Stateless HEEx rendering. Receive assigns, return markup. Zero logic, zero
side effects.

```
DashboardComponents        — progress_ring, intake_card, summary_bar, etc.
```

## PubSub Design

**Topic:** `"user:#{user_id}"`

**Events and subscribers:**

| Event                      | Broadcaster         | Subscribers                                              |
|----------------------------|---------------------|----------------------------------------------------------|
| `:intake_created`          | HydrationTracking   | ProgressComponent, HistoryComponent, WeeklySummaryComponent |
| `:intake_deleted`          | HydrationTracking   | ProgressComponent, HistoryComponent, WeeklySummaryComponent |
| `:alarm_settings_updated`  | UserManagement      | ProgressComponent, NextAlarmComponent, AlarmSettingsComponent, WeeklySummaryComponent |

**Broadcast location:** Inside context functions, after successful DB operation.

**Payload:** Atom only (e.g., `:intake_created`). Each component reloads its
own data from the context to avoid stale state.

**Example flow — logging water:**
1. User fills form -> `IntakeFormComponent.handle_event("save", ...)`
2. Calls `HydrationTracking.create_water_intake(user_id, attrs)`
3. Context inserts into DB, broadcasts `:intake_created` on `"user:42"`
4. ProgressComponent, HistoryComponent, WeeklySummaryComponent receive
   `handle_info(:intake_created, socket)` and reload their data

## Screen Layout

Single page, responsive grid (daisyUI cards). Collapses to single column on
mobile.

```
+--------------------------------------------------+
|  Header: "Hydration Dashboard" + user name       |
+------------------------+-------------------------+
|                        |                         |
|  Progress Ring         |  Log Water              |
|  (consumption vs goal) |  (quick btns + custom)  |
|  1500/2000ml — 75%     |                         |
|                        |                         |
+------------------------+-------------------------+
|                        |                         |
|  Next Alarm            |  Alarm Settings         |
|  "Next in 23min"       |  (goal, interval, times)|
|  "14:30 -> 14:53"      |  + Edit button -> modal |
|                        |                         |
+------------------------+-------------------------+
|                                                  |
|  Today's History                                 |
|  +----------+---------+-------+                  |
|  | 14:30    | 250ml   |   x   |                  |
|  | 12:15    | 500ml   |   x   |                  |
|  | 10:00    | 300ml   |   x   |                  |
|  +----------+---------+-------+                  |
|                                                  |
+--------------------------------------------------+
|                                                  |
|  Weekly Summary                                  |
|  +--+--+--+--+--+--+--+                         |
|  |Mo|Tu|We|Th|Fr|Sa|Su|  (vertical bars)        |
|  +--+--+--+--+--+--+--+                         |
|                                                  |
+--------------------------------------------------+
```

**Component details:**
- **Progress Ring** — SVG circular, updates in real-time via PubSub
- **Log Water** — quick buttons (150ml, 250ml, 500ml) + custom volume field + save button
- **Next Alarm** — calculated from `daily_start_time`, `daily_end_time`,
  `interval_minutes` and current time. Simple text, no live countdown.
- **Alarm Settings** — displays current values, "Edit" button opens modal with form
- **Today's History** — ordered by time desc, delete button on each row
- **Weekly Summary** — vertical bars with CSS/daisyUI, no external chart library

## Sub-steps

Each sub-step builds on the previous one.

| Sub-step | Description | Deliverable |
|----------|-------------|-------------|
| **8a** | Base structure — DashboardLive, `/dashboard` route, grid layout, hardcoded user (John Doe), PubSub subscribe | Empty page with header and placeholder cards |
| **8b** | Daily progress — `daily_progress/3` in context, ProgressComponent, SVG progress ring | Card showing consumption vs goal |
| **8c** | Today's history — `list_daily_intakes/2` in context, HistoryComponent, list with delete | Card with intake list, functional delete button |
| **8d** | Log water — IntakeFormComponent, form with quick buttons + custom, broadcast `:intake_created` | Functional form, ProgressComponent and HistoryComponent update in real-time |
| **8e** | Weekly summary — `weekly_summary/3` in context, WeeklySummaryComponent, CSS bars | Card with bars for last 7 days |
| **8f** | Next alarm — NextAlarmComponent, calculation from AlarmSettings + current time | Card showing next alarm time |
| **8g** | Edit alarm settings — AlarmSettingsComponent, modal with form, broadcast `:alarm_settings_updated` | Functional modal, dependent components update in real-time |

**Step 8d is the key milestone** — it proves the full PubSub reactivity loop works.

## Testing Strategy

**Behavior-driven tests** — test what the user sees and does, not implementation
details.

### Context tests (unit)

- `daily_progress/3` — no intakes returns zero, partial intakes returns correct
  percentage, goal reached returns 100%
- `list_daily_intakes/2` — empty day, multiple intakes ordered by time desc
- `weekly_summary/3` — days with no data in the middle, full week
- PubSub broadcasts — verify that `create_water_intake`, `delete_water_intake`,
  and `update_alarm_settings` broadcast the correct event on the correct topic

### LiveView tests (behavior)

Examples of good test descriptions:
- "when the user logs 250ml, the progress updates from 1500ml to 1750ml"
- "when the user deletes an intake, it disappears from the list"
- "when the form receives volume 0, it shows an error message"
- "when an intake is created, the weekly summary bar for today grows"

Examples of what NOT to test:
- CSS classes or styling details
- Internal assigns or socket state
- Function component rendering in isolation (tested indirectly)

**i18n in tests:** Assertions use `gettext` calls, not hardcoded strings.

## Roadmap Update

After absorbing Step 9 into Step 8, the roadmap renumbers:

| New # | Description | Old # |
|-------|-------------|-------|
| Step 8 (8a-8g) | LiveView dashboard + PubSub | Steps 8 + 9 |
| Step 9 | Background jobs with Oban | Step 10 |
| Step 10 | Keycloak/OAuth2 integration | Step 11 |
| Step 11 | public_id field on User | Step 12 |
| Step 12 | Scope-based authorization | Step 13 |
