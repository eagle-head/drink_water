# Step 8i: Full daisyUI Migration — Components + Design System

## Overview

Comprehensive migration from raw Tailwind patterns to daisyUI-first design.
Covers components (radial-progress, stat, list, join, tooltip, countdown,
divider, skeleton, swap, fieldset, validator) AND design system patterns
(typography, secondary text, form layout, button groups).

**Goal:** After this step, every UI pattern uses daisyUI where one exists.
Raw Tailwind is only used for layout utilities (flex, grid, spacing, sizing)
where daisyUI has no equivalent.

**Route:** `/dashboard` (unchanged)
**No new features.** Same data displayed, better semantic HTML, consistent
design system. Some display layouts change (e.g., progress ring text
reorganized into `stat` structure) but all information is preserved.

## Migrations

### 1. `radial-progress` + `stat` — ProgressComponent

**Before:**
- Custom SVG with `circumference`, `stroke-dasharray`, `stroke-dashoffset`
  calculated manually in `DashboardComponents.progress_ring/1`
- Text with `text-2xl font-bold` and `text-base-content/60`

**After:**
- daisyUI `stat` container with `radial-progress` as `stat-figure`
- `stat-title`, `stat-value`, `stat-desc` for text hierarchy

```heex
<div class="stat place-items-center">
  <div class="stat-figure text-primary">
    <div
      class="radial-progress text-primary"
      style={"--value:#{@percentage}; --size:5rem; --thickness:0.5rem;"}
      role="progressbar"
    >
      {@percentage |> Float.round(0) |> trunc()}%
    </div>
  </div>
  <div class="stat-value">{@total_ml}ml</div>
  <div class="stat-desc">
    {gettext("Goal")}: {@goal}ml — {ngettext("1 intake", "%{count} intakes", @intake_count)}
  </div>
</div>
```

**Content reorganization:** The current `progress_ring` shows
`{total_ml}ml / {goal}ml` as the large text and `{percentage}%` as secondary.
The `stat` layout reorganizes: `stat-value` shows `{total_ml}ml`, percentage
moves inside `radial-progress`, and goal + intake count move to `stat-desc`.
All information is preserved, just restructured for the `stat` semantic.

**Removes:** `DashboardComponents.progress_ring/1` entirely.

### 2. `list` + `list-row` — HistoryComponent

**Before:** `<table class="table">` with `thead/tbody/tr/td`.

**After:** `<ul class="list bg-base-200 rounded-box">` with
`<li class="list-row">` per intake.

```heex
<ul class="list bg-base-200 rounded-box">
  <li :for={intake <- @intakes} class="list-row" data-intake-id={intake.id}>
    <div class="font-mono">
      {Calendar.strftime(intake.date_time_utc, "%H:%M")}
    </div>
    <div class="list-col-grow font-bold">{intake.volume}ml</div>
    <div class="join">
      <button class="join-item btn btn-ghost btn-xs" phx-click="edit" ...>
        <.icon name="hero-pencil-square" class="size-4" />
      </button>
      <button class="join-item btn btn-ghost btn-xs text-error" phx-click="delete" ...>
        <.icon name="hero-x-mark" class="size-4" />
      </button>
    </div>
  </li>
</ul>
```

**Preserves `data-intake-id`** on each `list-row` so existing tests work.

### 3. `join` — Navigation buttons + action button groups

**Navigation buttons in HistoryComponent:**

**Before:** Three `btn btn-ghost btn-xs` with `flex gap-1`.

**After:** `<div class="join">` with `join-item` buttons.

The "Today" button is currently conditionally rendered (`<%= unless
@is_today do %>`). With `join`, we keep the conditional rendering — the
Today button only appears inside the `join` when viewing a past day. The
`join` component handles variable children gracefully.

```heex
<div class="join">
  <button class="join-item btn btn-ghost btn-xs" phx-click="nav-prev">
    <.icon name="hero-chevron-left" class="size-4" />
  </button>
  <%= unless @is_today do %>
    <button class="join-item btn btn-ghost btn-xs" phx-click="nav-today">
      {gettext("Today")}
    </button>
  <% end %>
  <button class={"join-item btn btn-ghost btn-xs #{if @is_today, do: "btn-disabled"}"}
    disabled={@is_today} phx-click="nav-next">
    <.icon name="hero-chevron-right" class="size-4" />
  </button>
</div>
```

**Action buttons in forms (AlarmSettings, EditIntake):**

**Before:** `<div class="flex gap-2">` with save/cancel buttons.

**After:** `<div class="join">` with `join-item` buttons.

### 4. `tooltip` — Weekly chart bars

**Before:** Native HTML `title={"#{day.total_ml}ml / #{day.goal}ml"}`.

**After:** daisyUI `tooltip` wrapper.

```heex
<div class="tooltip tooltip-top" data-tip={"#{day.total_ml}ml / #{day.goal}ml"}>
  <div class="bg-primary rounded-t ..." style={"height: ..."} />
</div>
```

### 5. `countdown` — NextAlarmComponent

**Before:** Static text "18:00".

**After:** Live countdown showing "Next in HH:MM" using daisyUI `countdown`
component with CSS `--value` variables.

```heex
<p class="font-mono text-2xl">
  <span class="countdown">
    <span style={"--value:#{@hours_left};"}></span>
  </span>
  :
  <span class="countdown">
    <span style={"--value:#{@minutes_left};"}></span>
  </span>
</p>
<p class="label">{gettext("until next alarm")}</p>
```

**Logic change:** DashboardLive schedules `:tick_next_alarm` every 60 seconds
via `Process.send_after(self(), :tick_next_alarm, 60_000)` in `mount/3`
(guarded by `connected?/1`). The `handle_info` calls `send_update` on
NextAlarmComponent, which recalculates time remaining.

NextAlarmComponent calculates `hours_left` and `minutes_left` from the
difference between `next_alarm` time and the current time.

**Timer re-arming:** `Process.send_after` fires once. The `handle_info`
for `:tick_next_alarm` must call `Process.send_after(self(),
:tick_next_alarm, 60_000)` again before returning, creating a recurring
timer. No cleanup needed — when the LiveView process dies, pending
messages are discarded.

### 6. `divider` — Between dashboard sections

**Before:** Cards separated by `mt-4` only.

**After:** `<div class="divider"></div>` between the 2x2 grid, history card,
and weekly summary card.

### 7. `skeleton` — Loading states (deferred)

**Status: DEFERRED.** The original plan was to migrate to `assign_async/3`
with `skeleton` placeholders. However, `assign_async` in LiveComponent
`update/2` has a correctness problem: every PubSub-triggered `send_update`
invokes `update/2`, which would restart the async task and briefly flash the
skeleton state in production. This creates a poor UX where data flickers
on every real-time update.

The current synchronous data loading in `update/2` is fast (single DB query
per component, single-user dashboard) and produces no flicker. The
`skeleton` + `assign_async` migration will be revisited when the dashboard
has multiple users or noticeably slow queries.

**No changes in this step.** The `skeleton` component remains available for
future use but is not applied to existing components.

### 8. `swap` — AlarmSettingsComponent toggle (dropped)

**Status: DROPPED.** The daisyUI `swap` component uses CSS (`display: none` /
`display: grid`) to toggle visibility, meaning both the display view AND the
edit form would always be in the DOM. This has drawbacks:

- Hidden form inputs could be accidentally submitted
- Screen readers would read hidden form content
- No benefit over server-side conditional rendering for server-driven state

The current `<%= unless @editing do %>` / `<% else %>` pattern is correct —
it only renders the active view, producing lighter DOM and no accessibility
issues. **No changes in this step.**

`swap` is appropriate for client-side toggles (e.g., icon animations) where
server round-trip is too slow. For server-controlled state like `@editing`,
conditional rendering is the right pattern.

### 9. `fieldset` + `fieldset-legend` — Form containers

**Before:** `<div class="form-control">` + `<label class="label">` + input
manually assembled in AlarmSettings, EditIntake, IntakeForm.

**After:** `<fieldset class="fieldset">` + `<legend class="fieldset-legend">`
wrapping each form field group.

```heex
<fieldset class="fieldset">
  <legend class="fieldset-legend">{gettext("Volume (ml)")}</legend>
  <input type="number" class="input input-bordered w-full" ... />
  <p :if={error} class="validator-hint text-error">{error}</p>
</fieldset>
```

**Applies to:** AlarmSettingsComponent, EditIntakeComponent, IntakeFormComponent.

### 10. Error messages — `label text-error` (not `validator`)

**Before:** `<.error>` from CoreComponents renders `<p class="mt-1.5 flex
gap-2 items-center text-sm text-error">`.

**After:** Use `<p class="label text-error text-xs">` for error messages.

**Why not `validator` / `validator-hint`:** daisyUI's `validator-hint` relies
on the browser's CSS `:invalid` pseudo-class, which is based on HTML5
constraint validation (`required`, `min`, `max` attributes). Our validation
is server-side via Ecto changesets — the browser never marks the input as
`:invalid`, so `validator-hint` would never show. The `label text-error`
approach uses daisyUI semantic classes and works with server-rendered errors.

```heex
<fieldset class="fieldset">
  <legend class="fieldset-legend">{gettext("Volume (ml)")}</legend>
  <input type="number" class="input input-bordered w-full" ... />
  <p :for={error <- @form[:volume].errors} class="label text-error text-xs">
    <.icon name="hero-exclamation-circle" class="size-4" />
    {translate_error(error)}
  </p>
</fieldset>
```

### 11. Typography — `card-title`, `stat-value`, `label`

**All heading patterns migrated:**

| Before (Tailwind) | After (daisyUI) | Where |
|---|---|---|
| `text-2xl font-bold mb-6` | `card-title text-2xl` | dashboard h1 |
| `text-2xl font-bold mt-2` | `stat-value` | progress ring value |
| `text-xl font-bold` | `stat-value` | next alarm time |
| `text-lg font-bold mb-4` | `card-title` | edit intake modal title |
| `card-title mb-4` | `card-title` | all section headings (keep) |

**All secondary text patterns migrated:**

| Before (Tailwind) | After (daisyUI) | Where |
|---|---|---|
| `text-base-content/60` | `label` | empty states, descriptions, alarm info |
| `text-sm text-base-content/70` | `label` | core_components header subtitle |
| `text-base-content/60` + `text-sm` | `stat-desc` | progress stats description |

**What stays as Tailwind (correct):**
- `text-sm text-base-content/40` for tertiary/fine-print text (no daisyUI equiv)
- `font-mono` for time displays
- `font-medium` for emphasis in data lists
- All `w-*`, `h-*`, `size-*` icon sizing
- All responsive classes (`md:grid-cols-2`)
- All flex/grid layout utilities

## File Changes

### Modified files

| File | Changes |
|---|---|
| `lib/drink_water_web/live/progress_component.ex` | Remove `progress_ring` import; use `stat` + `radial-progress` |
| `lib/drink_water_web/components/dashboard_components.ex` | Remove `progress_ring/1`; add `tooltip` wrapper to `weekly_chart` bars |
| `lib/drink_water_web/live/history_component.ex` | `table` → `list`/`list-row`; `join` for nav buttons and action buttons; `label` for empty state |
| `lib/drink_water_web/live/intake_form_component.ex` | `fieldset`/`fieldset-legend` for form fields |
| `lib/drink_water_web/live/weekly_summary_component.ex` | No changes (skeleton deferred) |
| `lib/drink_water_web/live/next_alarm_component.ex` | `countdown` display; `stat-value` for time; `label` for descriptions |
| `lib/drink_water_web/live/alarm_settings_component.ex` | `fieldset`/`fieldset-legend` for form; `label` for descriptions; `join` for action buttons (swap dropped) |
| `lib/drink_water_web/live/edit_intake_component.ex` | `card-title` for heading; `fieldset`/`fieldset-legend` for form; `join` for action buttons |
| `lib/drink_water_web/live/dashboard_live.ex` | Add `:tick_next_alarm` timer in mount; `handle_info` for tick; `assign_async` awareness |
| `lib/drink_water_web/live/dashboard_live.html.heex` | `divider` between sections; `card-title` for h1; remove `<h2>` from Progress card |
| `lib/drink_water_web/components/core_components.ex` | Update `error/1` to use `label text-error text-xs` |
| `test/drink_water_web/live/dashboard_live_test.exs` | Update assertions: `table`/`tr` → `list`/`list-row` |
| `test/drink_water_web/live/history_component_test.exs` | Update for `list` structure |
| `test/drink_water_web/live/next_alarm_component_test.exs` | Add countdown assertions |

### Deleted code

| What | Where |
|---|---|
| `progress_ring/1` | `dashboard_components.ex` — replaced by `radial-progress` + `stat` |

### No changes

- `UserManagement`, `HydrationTracking` contexts — no changes
- `NextAlarmComponent` `calculate_next_alarm` logic — unchanged, just display changes
- `router.ex` — no route changes

## Testing Strategy

**Template changes:** Assertions referencing `table`, `tr`, `thead` must be
updated to `list`, `list-row`. The `data-intake-id` attribute is preserved.

**`countdown`:** Tested with injected `now` (already supported). Verify
`hours_left` and `minutes_left` calculation.

**`fieldset`:** Assert `fieldset-legend` text matches field labels.

**`divider`:** Assert `divider` class appears between sections.

## Sub-steps

| Sub-step | Deliverable |
|---|---|
| **8i-1** | Typography: `card-title`, `stat-value`, `label` across all components |
| **8i-2** | `radial-progress` + `stat` in ProgressComponent; remove `progress_ring` |
| **8i-3** | `list` + `list-row` + `join` in HistoryComponent |
| **8i-4** | `fieldset` + `fieldset-legend` in all forms (IntakeForm, AlarmSettings, EditIntake) |
| **8i-5** | `tooltip` in weekly chart |
| **8i-6** | `countdown` in NextAlarmComponent + timer in DashboardLive |
| **8i-7** | `divider` between sections |
| **8i-8** | `label text-error` for error messages in CoreComponents + forms |
