# Step 8: LiveView Dashboard with PubSub

## Overview

Single-page LiveView dashboard for real-time hydration tracking. Absorbs the
original Step 9 (PubSub integration) since a LiveView without reactivity
defeats the purpose.

**Route:** `/dashboard` (browser pipeline)
**User:** Hardcoded John Doe from seeds (until Step 10/auth)
**i18n:** All strings via `gettext`, default locale `en`

> **Note:** The existing `/dev/dashboard` (LiveDashboard) is scoped under `/dev`
> and does not conflict with `/dashboard`. They are separate routes.

## Architecture: 3 Layers

### Layer 1 — Contexts (Business Logic)

Pure business logic. No knowledge of LiveView. Contexts broadcast PubSub
events after successful mutations so that any caller (LiveView, REST, Oban)
triggers real-time updates.

**Broadcasts are added to existing context functions** (`create_water_intake`,
`delete_water_intake`, `update_alarm_settings`). This means REST API callers
also trigger broadcasts — this is intentional so that any mutation source
feeds the real-time dashboard.

**HydrationTracking — new functions:**

```elixir
daily_progress(user_id, date, goal)
# => %{total_ml: 1500, goal: 2000, percentage: 75.0, intake_count: 6}
# `goal` comes from AlarmSettings.goal (integer, in ml)

list_daily_intakes(user_id, date)
# => [%WaterIntake{}, ...]   (no pagination, simple list, ordered by time desc)
# Justification: the existing list_water_intakes/2 supports cursor pagination
# and filtering, which is overkill for the dashboard's "show all of today" use
# case. A dedicated function is simpler and avoids coupling LiveView to the
# pagination API.

weekly_summary(user_id, end_date, goal)
# => [%{date: ~D[2026-03-10], total_ml: 1800, goal: 2000}, ...]
# Returns the 7 days ending on `end_date` (inclusive).
# Example: weekly_summary(user_id, ~D[2026-03-16], 2000) returns Mar 10-16.
# Days with no intakes appear with total_ml: 0.
# Note: a single `goal` value is applied to all 7 days. If the user changes
# their goal mid-week, historical days show against the current goal. This is
# a conscious simplification — per-day goal tracking is out of scope.

delete_water_intake_by_id(user_id, intake_id)
# => {:ok, %WaterIntake{}} | {:error, :not_found, :water_intake}
# Convenience function: looks up by (user_id, id), then deletes.
# Needed because HistoryComponent only knows the intake id, not the struct.
# This function does NOT call delete_water_intake/1 internally — it performs
# its own lookup + delete + broadcast to avoid double broadcasts.
```

**UserManagement — no new functions:**

- `get_user/1` and `get_alarm_settings_by_user/1` already exist.

**Cross-context boundary:** The LiveView fetches `goal` from
`UserManagement.get_alarm_settings_by_user/1` and passes it as an argument to
HydrationTracking functions. HydrationTracking never queries UserManagement
directly.

**Edge case — no alarm settings:** If `get_alarm_settings_by_user/1` returns
`{:error, :not_found, :alarm_settings}`, the dashboard uses a default goal of
2000ml and shows a message prompting the user to configure their settings.

### Layer 2 — Live Components (State + Orchestration)

Stateful components that manage their own assigns, call contexts on events,
and delegate rendering to function components.

```
DashboardLive              — mount, handle_params, layout grid, PubSub subscribe
ProgressComponent          — daily progress (consumption vs goal)
HistoryComponent           — list of today's intakes with delete
IntakeFormComponent        — form to log water intake
WeeklySummaryComponent     — last 7 days summary
NextAlarmComponent         — next alarm info
AlarmSettingsComponent     — view/edit alarm settings (modal)
```

**DashboardLive lifecycle (mount vs handle_params):**

Per the Phoenix Iron Law — no DB queries in `mount/3`:

- `mount/3`: PubSub subscribe (guarded by `connected?/1`), assign empty
  defaults. No DB calls.
- `handle_params/3`: Load user, alarm settings, goal. Push initial data to
  child components.

```elixir
# mount/3 — subscribe only when WebSocket is connected (not during static render)
def mount(_params, _session, socket) do
  if connected?(socket) do
    Phoenix.PubSub.subscribe(DrinkWater.PubSub, "user:#{@hardcoded_user_id}")
  end

  {:ok, assign_defaults(socket)}
end

# handle_params/3 — load data here, not in mount
def handle_params(_params, _uri, socket) do
  # load user, alarm_settings, goal
  # push initial data to children via send_update or assigns
  {:noreply, load_dashboard_data(socket)}
end
```

**PubSub subscription pattern:** DashboardLive subscribes once to the topic
`"user:#{user_id}"` and handles all `handle_info` callbacks. It then uses
`send_update/2` to push updates to the relevant child components. This avoids
6 redundant subscriptions to the same topic and follows the standard Phoenix
parent-dispatches pattern.

### Layer 3 — Function Components (Pure UI)

Stateless HEEx rendering. Receive assigns, return markup. Zero logic, zero
side effects.

```
DashboardComponents        — progress_ring, intake_card, summary_bar, etc.
```

## PubSub Design

**Topic:** `"user:#{user_id}"`

**Subscription:** DashboardLive subscribes once in `mount/3`, guarded by
`connected?/1`.

**Events and affected components:**

| Event                      | Broadcaster         | DashboardLive dispatches to                              |
|----------------------------|---------------------|----------------------------------------------------------|
| `:intake_created`          | HydrationTracking   | ProgressComponent, HistoryComponent, WeeklySummaryComponent |
| `:intake_deleted`          | HydrationTracking   | ProgressComponent, HistoryComponent, WeeklySummaryComponent |
| `:alarm_settings_updated`  | UserManagement      | ProgressComponent, NextAlarmComponent, AlarmSettingsComponent, WeeklySummaryComponent |

**Broadcast location:** Inside existing context functions, after successful DB
operation. Added to: `HydrationTracking.create_water_intake/2`,
`HydrationTracking.delete_water_intake/1`, and
`UserManagement.update_alarm_settings/2`. The new
`HydrationTracking.delete_water_intake_by_id/2` handles its own broadcast
independently (does not delegate to `delete_water_intake/1`) to avoid double
broadcasts.

**Payload:** Atom only (e.g., `:intake_created`). Each component reloads its
own data from the context to avoid stale state.

**Example flow — logging water:**

1. User fills form -> `IntakeFormComponent.handle_event("save", ...)`
2. Calls `HydrationTracking.create_water_intake(user_id, attrs)`
3. Context inserts into DB, broadcasts `:intake_created` on `"user:42"`
4. DashboardLive receives `handle_info(:intake_created, socket)`
5. DashboardLive calls `send_update` to ProgressComponent, HistoryComponent,
   WeeklySummaryComponent — each reloads its data from context

**Example flow — deleting an intake:**

1. User clicks delete on an intake row -> `HistoryComponent.handle_event("delete", %{"id" => id}, ...)`
2. Calls `HydrationTracking.delete_water_intake_by_id(user_id, id)`
3. Context deletes from DB, broadcasts `:intake_deleted` on `"user:42"`
4. DashboardLive dispatches to ProgressComponent, HistoryComponent, WeeklySummaryComponent
5. If the intake was already deleted (race condition, e.g., two tabs), the
   context returns `{:error, :not_found, :water_intake}` and the component
   shows a flash message "Intake already removed" — no crash.

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
- **Log Water** — quick buttons (150ml, 250ml, 500ml) + custom volume field +
  save button. `date_time_utc` is set automatically to `DateTime.utc_now()`
  and `volume_unit` defaults to `:ml` — the user only picks the volume.
  **Error handling:** validation errors from the changeset display inline below
  the volume field (e.g., "must be between 1 and 5000"). On success, the
  component resets the form by reassigning a fresh changeset
  (`assign(socket, form: to_form(empty_changeset))`) and shows a flash message
  confirming the entry.
- **Next Alarm** — calculated from `daily_start_time`, `daily_end_time`,
  `interval_minutes` and current time. Simple text, no live countdown.
- **Alarm Settings** — displays current values, "Edit" button opens a daisyUI
  modal (custom component — the project's core_components.ex does not include
  Phoenix's generated `<.modal>`). Validation errors display inline in the
  modal.
- **Today's History** — ordered by time desc, delete button on each row
- **Weekly Summary** — vertical bars with CSS/daisyUI, no external chart library

**Input sanitization:** LiveView forms go through the browser pipeline (with
CSRF protection). Input validation is handled by Ecto changesets in the
contexts — the same validation used by the REST API. The `InputSanitizer` plug
is API-pipeline specific and not needed for LiveView since changesets already
enforce data integrity.

**Responsiveness:** On mobile, the grid collapses to a single column (stack
vertical).

## Known Limitations

- **Timezone:** "Today" is defined as the UTC date (`DateTime.utc_now()`).
  For a user in UTC-3 (e.g., Brazil), at 23:00 local time the UTC date is
  already the next day. This is a known limitation acceptable for a hardcoded
  single-user dev setup. Proper timezone handling will be addressed when auth
  and user preferences are added (Step 10+).

- **Seed data:** The existing seeds use dates from 2024-08-14. On first load
  after `mix ecto.setup`, the dashboard will show zero intakes and an empty
  weekly summary. This is expected — the user can log intakes via the form.
  Seeds may optionally be updated to use relative dates for a better dev
  experience, but this is not a blocker.

- **Weekly goal consistency:** `weekly_summary/3` applies a single `goal`
  value to all 7 days. Mid-week goal changes are not tracked historically.

## Performance Notes

- **assign_async:** The spec uses synchronous data loading in `handle_params`
  for simplicity. For a single-user dashboard this is adequate. If load times
  become noticeable, `assign_async/3` can be introduced to render the page
  shell immediately while data loads in the background. This is not needed for
  Step 8 but is noted as an available optimization.

## Sub-steps

Each sub-step builds on the previous one.

| Sub-step | Description | Deliverable |
|----------|-------------|-------------|
| **8a** | Base structure — DashboardLive with mount/handle_params split, `/dashboard` route, grid layout, hardcoded user (John Doe), PubSub subscribe with `connected?/1` guard | Empty page with header and placeholder cards |
| **8b** | Daily progress — `daily_progress/3` in context, ProgressComponent, SVG progress ring | Card showing consumption vs goal |
| **8c** | Today's history — `list_daily_intakes/2` and `delete_water_intake_by_id/2` in context, HistoryComponent, list with delete, add broadcast `:intake_deleted` to both `delete_water_intake/1` and `delete_water_intake_by_id/2` | Card with intake list, functional delete that updates ProgressComponent in real-time |
| **8d** | Log water — IntakeFormComponent, form with quick buttons + custom, add broadcast `:intake_created` to `create_water_intake/2`, error handling with inline validation, form reset on success | Functional form, ProgressComponent and HistoryComponent update in real-time |
| **8e** | Weekly summary — `weekly_summary/3` in context, WeeklySummaryComponent, CSS bars | Card with bars for last 7 days |
| **8f** | Next alarm — NextAlarmComponent, calculation from AlarmSettings + current time | Card showing next alarm time |
| **8g** | Edit alarm settings — AlarmSettingsComponent, daisyUI modal with form, add broadcast `:alarm_settings_updated` to `update_alarm_settings/2` | Functional modal, dependent components update in real-time |

**Step 8d is the key milestone** — it proves the full PubSub reactivity loop
works (form submit -> context -> broadcast -> parent dispatches -> components
reload).

## Testing Strategy

**Behavior-driven tests** — test what the user sees and does, not
implementation details.

### Context tests (unit)

- `daily_progress/3` — no intakes returns zero, partial intakes returns correct
  percentage, goal reached returns 100%
- `list_daily_intakes/2` — empty day, multiple intakes ordered by time desc
- `weekly_summary/3` — days with no data in the middle, full 7-day range,
  verifies the 7 days ending on the given date
- `delete_water_intake_by_id/2` — existing intake, nonexistent intake
- PubSub broadcasts — verify that `create_water_intake`, `delete_water_intake`,
  `delete_water_intake_by_id`, and `update_alarm_settings` broadcast the correct
  event on the correct topic

### LiveView tests (behavior)

Examples of good test descriptions:

- "when the user logs 250ml, the progress updates from 1500ml to 1750ml"
- "when the user deletes an intake, it disappears from the list"
- "when the form receives volume 0, it shows an error message"
- "when an intake is created, the weekly summary bar for today grows"
- "when alarm settings do not exist, shows default goal and setup prompt"
- "when the user deletes an already-removed intake, shows an error flash"

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
