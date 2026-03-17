# Step 8h: Dashboard Enhancements — Date Navigation, Edit Intake, Success Flash

## Overview

Enhancements to the LiveView dashboard from Step 8. Adds date navigation
(browse history/progress for any day), edit intake (modal), click-to-navigate
on weekly summary bars, and success flash on water logging.

**Route:** `/dashboard` (unchanged)
**Spec dependency:** `2026-03-16-step8-liveview-dashboard-design.md`

## Features

### 1. Date Navigation

The dashboard gains a `selected_date` (default: `Date.utc_today()`) that
controls which day's data is shown in ProgressComponent and HistoryComponent.

**`selected_date` lives in DashboardLive** (parent), not in child components.
This is because multiple sources can change the date (weekly bar click,
history navigation buttons) and multiple consumers need it (Progress, History).

**What changes per date:**

| Component | Follows selected_date? | Reason |
|---|---|---|
| ProgressComponent | Yes | Shows progress for the selected day |
| HistoryComponent | Yes | Shows intakes for the selected day |
| IntakeFormComponent | No | Always logs for "now" (UTC) |
| NextAlarmComponent | No | Always shows next alarm from now |
| AlarmSettingsComponent | No | Settings are date-independent |
| WeeklySummaryComponent | Partially | Highlights the selected day's bar |

**Navigation controls in HistoryComponent:**

Buttons: `←` (previous day), `→` (next day), `Today` (reset).
- `Today` button only visible when `selected_date != Date.utc_today()`
- `→` button disabled when `selected_date == Date.utc_today()` (no future)

**Title changes:**
- Today: `"Today's History"` / `"Daily Progress"`
- Other day: `"History — Mar 11, 2026"` / `"Progress — Mar 11, 2026"`
  Format: `Calendar.strftime(date, "%b %d, %Y")`

**Communication pattern:**

Navigation buttons and weekly bar clicks send messages to the parent:
```elixir
# From HistoryComponent or WeeklySummaryComponent
send(self(), {:select_date, date})
```

DashboardLive handles in `handle_info`:
```elixir
def handle_info({:select_date, date}, socket) do
  send_update(ProgressComponent, id: "progress", user_id: ..., goal: ..., selected_date: date)
  send_update(HistoryComponent, id: "history", user_id: ..., selected_date: date)
  send_update(WeeklySummaryComponent, id: "weekly-summary", ..., selected_date: date)
  {:noreply, assign(socket, selected_date: date)}
end
```

**PubSub behavior with selected_date:**

The conditional guard lives in `DashboardLive.handle_info` (the parent
orchestrates, children just reload their own data). When `:intake_created`,
`:intake_deleted`, or `:intake_updated` broadcasts arrive:

- WeeklySummaryComponent always reloads (the bar for today may have changed)
- If `socket.assigns.selected_date == Date.utc_today()`:
  call `send_update` for ProgressComponent and HistoryComponent
  (passing `selected_date: socket.assigns.selected_date`)
- Otherwise: skip ProgressComponent and HistoryComponent
  (don't disrupt the user's view of a past day)

The `:alarm_settings_updated` handler is **not** guarded by `selected_date` —
when the goal changes, ProgressComponent must reload regardless of the selected
day, because the percentage changes for any day (the goal is the denominator).

**Important:** All existing `send_update` calls for ProgressComponent and
HistoryComponent (in `:intake_created`, `:intake_deleted`, and
`:alarm_settings_updated` handlers) must pass `selected_date:
socket.assigns.selected_date` after this change. Components must handle this
assign safely with a default: `assigns[:selected_date] ||
socket.assigns[:selected_date] || Date.utc_today()`.

**The conditional PubSub guard must be implemented alongside the date
navigation** (not as a separate step), otherwise PubSub events will snap the
view back to today when the user is browsing a past day.

### 2. Weekly Summary Bar Click

Clicking a bar in the weekly chart sets `selected_date` to that day.

**Visual feedback:** The selected day's bar uses `bg-primary`, other bars use
`bg-primary/40` (reduced opacity). The `weekly_chart` function component
receives a new `selected_date` assign.

**Implementation:** Each bar div gets `phx-click="select-day"` and
`phx-value-date={date}` with `phx-target={@myself}`. The WeeklySummaryComponent
handles the event and sends `send(self(), {:select_date, date})` to the parent.

**Data range:** WeeklySummaryComponent always shows the 7 days ending on
`Date.utc_today()`. If `selected_date` is outside that window (more than 6 days
ago), no bar is highlighted. This is a known limitation acceptable for step 8h —
the weekly chart is a quick-glance widget, not a full calendar.

### 3. Edit Intake (Modal)

**New button:** Edit icon (pencil) next to the delete button in each
HistoryComponent table row.

**Flow:**
1. User clicks edit on an intake row
2. HistoryComponent sends `send(self(), {:edit_intake, intake_id})`
3. DashboardLive loads the intake via `HydrationTracking.get_water_intake/2`,
   assigns `@editing_intake`
4. Modal renders in `dashboard_live.html.heex` (not inside HistoryComponent)
5. User edits volume and/or date_time_utc, submits
6. `HydrationTracking.update_water_intake/2` saves and broadcasts `:intake_updated`
7. DashboardLive closes modal, dispatches updates to components

**Edge case — race condition on edit:** If `get_water_intake/2` returns
`{:error, :not_found, :water_intake}` (intake was deleted between page render
and the edit click), DashboardLive sends a flash error and does not open the
modal.

**Why the modal lives in DashboardLive:**
- Modal overlay must cover the full page
- LiveComponents should not render outside their container
- DashboardLive already orchestrates cross-component state

**New LiveComponent:** `EditIntakeComponent`
- Form with two fields: volume (number, 1-5000) and date_time_utc (datetime-local)
- `volume_unit` is always `:ml` (not editable)
- `phx-change="validate"` for inline validation
- `phx-submit="save"` calls `HydrationTracking.update_water_intake/2`
- Cancel button sends `send(self(), :cancel_edit_intake)` to parent

**Edge case:** If the user changes the date_time_utc to a different day, the
intake leaves the current day's list. The PubSub broadcast updates all
components automatically.

**New PubSub event:**

| Event | Broadcaster | DashboardLive dispatches to |
|---|---|---|
| `:intake_updated` | HydrationTracking | ProgressComponent, HistoryComponent, WeeklySummaryComponent |

Added to `HydrationTracking.update_water_intake/2` (currently does not
broadcast). The `user_id` for the broadcast is read from `water_intake.user_id`
— no signature change required. Current signature:
`update_water_intake(%WaterIntake{} = water_intake, attrs)`.

### 4. Success Flash on Water Logging

The `save` handler in `IntakeFormComponent` currently does not send a success
flash (step 8d gap — the original spec required "shows a flash message
confirming the entry" but it was not implemented). This step adds it.

After successfully creating an intake (both "save" and "quick-log" in
IntakeFormComponent), send a flash:

```elixir
send(self(), {:flash, :info, gettext("Water logged!")})
```

Uses the existing `{:flash, kind, message}` pattern already handled by
DashboardLive's `handle_info`.

## File Changes

### New files

| File | Responsibility |
|---|---|
| `lib/drink_water_web/live/edit_intake_component.ex` | Modal form for editing an intake |
| `test/drink_water_web/live/edit_intake_component_test.exs` | Edit intake tests |

### Modified files

| File | Changes |
|---|---|
| `lib/drink_water_web/live/dashboard_live.ex` | New assign `@selected_date`, `handle_info` for `:select_date`, `:edit_intake`, `:cancel_edit_intake`, `:intake_updated` dispatch; conditional PubSub guard; pass `selected_date` in all `send_update` calls for Progress/History |
| `lib/drink_water_web/live/dashboard_live.html.heex` | Pass `selected_date` to components, conditional modal for edit intake |
| `lib/drink_water_web/live/progress_component.ex` | Accept `selected_date` (with default `Date.utc_today()`), use it in `daily_progress/3`, dynamic title |
| `lib/drink_water_web/live/history_component.ex` | Accept `selected_date` (with default `Date.utc_today()`), navigation buttons (< > Today), edit button per row, dynamic title |
| `lib/drink_water_web/live/weekly_summary_component.ex` | Accept `selected_date` (with default `Date.utc_today()`), pass to chart for highlighting, handle "select-day" event |
| `lib/drink_water_web/live/intake_form_component.ex` | Add success flash via `send(self(), {:flash, :info, ...})` on both save and quick-log |
| `lib/drink_water_web/components/dashboard_components.ex` | `weekly_chart` accepts `selected_date` for bar highlighting |
| `lib/drink_water/hydration_tracking.ex` | Add broadcast `:intake_updated` to `update_water_intake/2` using `water_intake.user_id` |
| `test/drink_water_web/live/dashboard_live_test.exs` | Tests for date navigation, bar click, edit flow, success flash |
| `test/drink_water/pubsub_broadcast_test.exs` | Test for `:intake_updated` broadcast |

### No changes

- `NextAlarmComponent` — always shows current time
- `AlarmSettingsComponent` — date-independent
- `UserManagement` context — no new functions

## Testing Strategy

### Context tests

- `update_water_intake/2` broadcasts `:intake_updated` on success
- `update_water_intake/2` does not broadcast on failure

### LiveView tests

**Date navigation:**
- "when user clicks ← button, history shows previous day's intakes"
- "when user clicks Today button, history returns to today"
- "→ button is disabled when viewing today"
- "Today button is hidden when viewing today"
- "PubSub intake_created only updates progress when viewing today"
- "title shows date when viewing a past day"

**Weekly bar click:**
- "clicking a weekly bar changes history to that day"
- "selected bar has active styling"

**Edit intake:**
- "edit button opens modal with intake data pre-filled"
- "submitting valid edit updates the intake and closes modal"
- "submitting invalid edit shows validation errors in modal"
- "cancel closes modal without changes"
- "editing date_time_utc to another day removes intake from current view"
- "clicking edit on an already-deleted intake shows an error flash"

**Success flash:**
- "logging water via form shows success flash"
- "logging water via quick button shows success flash"

## Sub-steps

| Sub-step | Description | Deliverable |
|---|---|---|
| **8h-1** | Date navigation + PubSub guard — `selected_date` in DashboardLive, pass to Progress/History, navigation buttons, dynamic titles, conditional PubSub reload | Progress and History show data for selected day without being disrupted by broadcasts |
| **8h-2** | Weekly bar click — click handler in WeeklySummaryComponent, bar highlighting, sends `:select_date` | Clicking a bar navigates to that day |
| **8h-3** | Edit intake — EditIntakeComponent modal, edit button in History, broadcast `:intake_updated`, race condition handling | Functional edit modal with real-time updates |
| **8h-4** | Success flash — flash message on intake creation (step 8d gap) | Flash "Water logged!" on save and quick-log |
