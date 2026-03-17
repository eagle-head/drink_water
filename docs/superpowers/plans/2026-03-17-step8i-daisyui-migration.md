# Step 8i: Full daisyUI Migration Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate all hand-rolled UI patterns to daisyUI native components and design system classes.

**Architecture:** Pure template/CSS changes across 8 components + 1 function component + core_components. No logic changes except adding a 60-second timer for the countdown feature. All existing tests updated for new HTML structure.

**Tech Stack:** Phoenix LiveView, daisyUI v5 (radial-progress, stat, list, join, tooltip, countdown, divider, fieldset), Tailwind CSS, Gettext

**Spec:** `docs/superpowers/specs/2026-03-17-step8i-daisyui-migration-design.md`

---

## File Map

### Modified files

| File | Changes |
|---|---|
| `lib/drink_water_web/components/dashboard_components.ex` | Remove `progress_ring/1`; add `tooltip` to `weekly_chart` |
| `lib/drink_water_web/components/core_components.ex:303-310` | Update `error/1` to use `label text-error` |
| `lib/drink_water_web/live/progress_component.ex` | Replace `progress_ring` with `stat` + `radial-progress` |
| `lib/drink_water_web/live/history_component.ex:84-178` | `table` → `list`/`list-row`; nav → `join`; empty → `label` |
| `lib/drink_water_web/live/intake_form_component.ex:91-109` | `form-control` → `fieldset` |
| `lib/drink_water_web/live/alarm_settings_component.ex:110-187` | `form-control` → `fieldset`; descriptions → `label`; actions → `join` |
| `lib/drink_water_web/live/edit_intake_component.ex:52-101` | heading → `card-title`; `form-control` → `fieldset`; actions → `join` |
| `lib/drink_water_web/live/next_alarm_component.ex` | Add `countdown`; descriptions → `label`; time → `stat-value` |
| `lib/drink_water_web/live/dashboard_live.ex:16-23` | Add `:tick_next_alarm` timer in `mount` + `handle_info` |
| `lib/drink_water_web/live/dashboard_live.html.heex` | `divider` between sections; heading → `card-title` |
| `test/drink_water_web/live/dashboard_live_test.exs` | Update `table`/`tr` assertions to `list`/`list-row` |
| `test/drink_water_web/live/history_component_test.exs` | Update for `list` structure |
| `test/drink_water_web/live/next_alarm_component_test.exs` | Add countdown assertions |

---

## Chunk 1: Task 1 — Sub-step 8i-8 (Error messages — simplest, independent)

### Task 1: Update `error/1` in CoreComponents to use daisyUI `label text-error`

**Files:**

- Modify: `lib/drink_water_web/components/core_components.ex:303-310`

- [ ] **Step 1: Update error component**

In `lib/drink_water_web/components/core_components.ex`, replace the `error/1` function (lines 303-310):

```elixir
  def error(assigns) do
    ~H"""
    <p class="label text-error text-xs">
      <.icon name="hero-exclamation-circle" class="size-4" />
      {render_slot(@inner_block)}
    </p>
    """
  end
```

- [ ] **Step 2: Run mix precommit**

Run: `mix precommit`
Expected: All checks pass

- [ ] **Step 3: Commit**

```bash
git add lib/drink_water_web/components/core_components.ex
git commit -m "Step 8i-8: Migrate error messages to daisyUI label text-error"
```

---

## Chunk 2: Task 2 — Sub-step 8i-1 (Typography migration)

### Task 2: Migrate typography across all components

**Files:**

- Modify: `lib/drink_water_web/live/dashboard_live.html.heex:5`
- Modify: `lib/drink_water_web/live/next_alarm_component.ex:49-75`
- Modify: `lib/drink_water_web/live/alarm_settings_component.ex:74-101`
- Modify: `lib/drink_water_web/live/edit_intake_component.ex:55`

- [ ] **Step 1: Dashboard h1 → `card-title`**

In `lib/drink_water_web/live/dashboard_live.html.heex`, replace line 5:

```heex
  <h1 class="card-title text-2xl mb-6">
```

- [ ] **Step 2: NextAlarmComponent — `label` for descriptions**

Replace the `render/1` function in `lib/drink_water_web/live/next_alarm_component.ex` (lines 49-76):

```elixir
  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h2 class="card-title mb-4">{gettext("Next Alarm")}</h2>
      <%= if @alarm_settings == nil do %>
        <p class="label">{gettext("No alarm configured")}</p>
      <% else %>
        <%= if @next_alarm do %>
          <p class="stat-value text-xl">{Calendar.strftime(@next_alarm, "%H:%M")}</p>
          <p class="label">
            {gettext("Every %{minutes} min", minutes: @alarm_settings.interval_minutes)}
          </p>
          <p class="label text-xs opacity-40">
            {Calendar.strftime(@alarm_settings.daily_start_time, "%H:%M")} → {Calendar.strftime(
              @alarm_settings.daily_end_time,
              "%H:%M"
            )}
          </p>
        <% else %>
          <p class="label">{gettext("Done for today!")}</p>
          <p class="label text-xs opacity-40">
            {gettext("Every %{minutes} min", minutes: @alarm_settings.interval_minutes)}
          </p>
        <% end %>
      <% end %>
    </div>
    """
  end
```

- [ ] **Step 3: AlarmSettingsComponent — `label` for descriptions**

In `lib/drink_water_web/live/alarm_settings_component.ex`, replace descriptions in the display view (lines 82-101). Change all `text-base-content/60` to `label`:

```elixir
          <dl class="space-y-1 text-sm">
            <div class="flex justify-between">
              <dt class="label">{gettext("Goal")}</dt>
              <dd class="font-medium">{@alarm_settings.goal}ml</dd>
            </div>
            <div class="flex justify-between">
              <dt class="label">{gettext("Interval")}</dt>
              <dd class="font-medium">
                {@alarm_settings.interval_minutes} {gettext("min")}
              </dd>
            </div>
            <div class="flex justify-between">
              <dt class="label">{gettext("Hours")}</dt>
              <dd class="font-medium">
                {Calendar.strftime(@alarm_settings.daily_start_time, "%H:%M")} → {Calendar.strftime(
                  @alarm_settings.daily_end_time,
                  "%H:%M"
                )}
              </dd>
            </div>
          </dl>
```

Also change the nil state (line 79): `<p class="label">{gettext("No alarm configured")}</p>`

- [ ] **Step 4: EditIntakeComponent — `card-title` for heading**

In `lib/drink_water_web/live/edit_intake_component.ex`, replace line 55:

```heex
      <h3 class="card-title mb-4">{gettext("Edit Intake")}</h3>
```

- [ ] **Step 5: Update next_alarm tests for changed gettext key**

The gettext key changed from `"Every %{minutes} minutes"` to `"Every %{minutes} min"`.
Update assertions in `test/drink_water_web/live/next_alarm_component_test.exs`:

Replace `assert html =~ "Every 30 minutes"` with `assert html =~ "Every 30 min"` (2 occurrences).
Also update `test/drink_water_web/live/dashboard_live_test.exs` if any assertions reference the old string.

- [ ] **Step 6: Run mix precommit**

Run: `mix precommit`
Expected: All checks pass

- [ ] **Step 7: Commit**

```bash
git add lib/drink_water_web/live/dashboard_live.html.heex \
        lib/drink_water_web/live/next_alarm_component.ex \
        lib/drink_water_web/live/alarm_settings_component.ex \
        lib/drink_water_web/live/edit_intake_component.ex \
        test/drink_water_web/live/next_alarm_component_test.exs \
        test/drink_water_web/live/dashboard_live_test.exs
git commit -m "Step 8i-1: Migrate typography to daisyUI card-title, stat-value, label"
```

---

## Chunk 3: Task 3 — Sub-step 8i-2 (radial-progress + stat)

### Task 3: ProgressComponent — `radial-progress` + `stat`

**Files:**

- Modify: `lib/drink_water_web/live/progress_component.ex`
- Modify: `lib/drink_water_web/components/dashboard_components.ex`

- [ ] **Step 1: Replace ProgressComponent render with stat + radial-progress**

Replace `lib/drink_water_web/live/progress_component.ex` entirely:

```elixir
defmodule DrinkWaterWeb.ProgressComponent do
  use DrinkWaterWeb, :live_component

  alias DrinkWater.HydrationTracking

  @impl true
  def update(assigns, socket) do
    selected_date =
      assigns[:selected_date] || socket.assigns[:selected_date] || Date.utc_today()

    socket =
      socket
      |> assign(:user_id, assigns.user_id)
      |> assign(:goal, assigns.goal)
      |> assign(:selected_date, selected_date)
      |> load_progress()

    {:ok, socket}
  end

  defp load_progress(socket) do
    progress =
      HydrationTracking.daily_progress(
        socket.assigns.user_id,
        socket.assigns.selected_date,
        socket.assigns.goal
      )

    assign(socket, progress)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <%= if @selected_date != Date.utc_today() do %>
        <h2 class="card-title mb-2">
          {gettext("Progress")} — {Calendar.strftime(@selected_date, "%b %d, %Y")}
        </h2>
      <% end %>
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
    </div>
    """
  end
end
```

- [ ] **Step 2: Remove `progress_ring/1` from DashboardComponents**

In `lib/drink_water_web/components/dashboard_components.ex`, remove lines 10-52 (the `progress_ring` function and its attrs). Keep only `weekly_chart`.

- [ ] **Step 3: Fix test assertions for new stat layout**

The old `progress_ring` rendered `"0ml / 2000ml"` as a single string. The new
`stat` layout renders them separately (`stat-value` = `"0ml"`, `stat-desc` =
`"Goal: 2000ml"`). Update assertions in `test/drink_water_web/live/dashboard_live_test.exs`:

Replace `assert html =~ "0ml / 2000ml"` (PubSub guard test) with:
```elixir
assert html =~ "0ml"
```

Any other assertions that check for `"Xml / 2000ml"` format should be split
into separate assertions for `"Xml"` and `"2000ml"`.

- [ ] **Step 4: Run mix precommit**

Run: `mix precommit`
Expected: All checks pass

- [ ] **Step 5: Commit**

```bash
git add lib/drink_water_web/live/progress_component.ex \
        lib/drink_water_web/components/dashboard_components.ex \
        test/drink_water_web/live/dashboard_live_test.exs
git commit -m "Step 8i-2: Replace progress_ring SVG with daisyUI radial-progress + stat"
```

---

## Chunk 4: Task 4 — Sub-step 8i-3 (list + join in History)

### Task 4: HistoryComponent — `list` + `list-row` + `join`

**Files:**

- Modify: `lib/drink_water_web/live/history_component.ex:84-178`
- Modify: `test/drink_water_web/live/dashboard_live_test.exs`
- Modify: `test/drink_water_web/live/history_component_test.exs`

- [ ] **Step 1: Replace HistoryComponent render with list + join**

Replace the `render/1` function in `lib/drink_water_web/live/history_component.ex` (lines 84-178):

```elixir
  @impl true
  def render(assigns) do
    assigns = assign(assigns, :is_today, is_today?(assigns.selected_date))

    ~H"""
    <div>
      <div class="flex items-center justify-between mb-4">
        <%= if @is_today do %>
          <h2 class="card-title">{gettext("Today's History")}</h2>
        <% else %>
          <h2 class="card-title">
            {gettext("History")} — {Calendar.strftime(@selected_date, "%b %d, %Y")}
          </h2>
        <% end %>

        <div class="join">
          <button
            phx-click="nav-prev"
            phx-target={@myself}
            class="join-item btn btn-ghost btn-xs"
            title={gettext("Previous day")}
          >
            <.icon name="hero-chevron-left" class="size-4" />
          </button>

          <%= unless @is_today do %>
            <button
              phx-click="nav-today"
              phx-target={@myself}
              class="join-item btn btn-ghost btn-xs"
            >
              {gettext("Today")}
            </button>
          <% end %>

          <button
            phx-click="nav-next"
            phx-target={@myself}
            class={"join-item btn btn-ghost btn-xs #{if @is_today, do: "btn-disabled"}"}
            disabled={@is_today}
            title={gettext("Next day")}
          >
            <.icon name="hero-chevron-right" class="size-4" />
          </button>
        </div>
      </div>

      <%= if @intakes == [] do %>
        <p class="label">
          <%= if @is_today do %>
            {gettext("No water logged today")}
          <% else %>
            {gettext("No water logged on this day")}
          <% end %>
        </p>
      <% else %>
        <ul class="list bg-base-200 rounded-box">
          <li :for={intake <- @intakes} class="list-row" data-intake-id={intake.id}>
            <div class="font-mono">{Calendar.strftime(intake.date_time_utc, "%H:%M")}</div>
            <div class="list-col-grow font-bold">{intake.volume}ml</div>
            <div class="join">
              <button
                phx-click="edit"
                phx-value-id={intake.id}
                phx-target={@myself}
                class="join-item btn btn-ghost btn-xs"
              >
                <.icon name="hero-pencil-square" class="size-4" />
              </button>
              <button
                phx-click="delete"
                phx-value-id={intake.id}
                phx-target={@myself}
                class="join-item btn btn-ghost btn-xs text-error"
              >
                <.icon name="hero-x-mark" class="size-4" />
              </button>
            </div>
          </li>
        </ul>
      <% end %>
    </div>
    """
  end
```

- [ ] **Step 2: Run tests — fix any assertion mismatches**

Run: `mix test test/drink_water_web/live/dashboard_live_test.exs test/drink_water_web/live/history_component_test.exs`

Assertions that reference `table`, `tr`, `thead` should be fine because they were checking for text content (`"250"`, `"350"`), not HTML structure. The `data-intake-id` attribute is preserved on `list-row` items. If any tests fail, update the selectors.

- [ ] **Step 3: Run mix precommit**

Run: `mix precommit`
Expected: All checks pass

- [ ] **Step 4: Commit**

```bash
git add lib/drink_water_web/live/history_component.ex \
        test/drink_water_web/live/dashboard_live_test.exs \
        test/drink_water_web/live/history_component_test.exs
git commit -m "Step 8i-3: Migrate History to daisyUI list/list-row + join nav buttons"
```

---

## Chunk 5: Task 5 — Sub-step 8i-4 (fieldset in all forms)

### Task 5: Migrate all forms to `fieldset` + `fieldset-legend`

**Files:**

- Modify: `lib/drink_water_web/live/intake_form_component.ex:91-109`
- Modify: `lib/drink_water_web/live/alarm_settings_component.ex:110-187`
- Modify: `lib/drink_water_web/live/edit_intake_component.ex:56-101`

- [ ] **Step 1: IntakeFormComponent — `fieldset`**

In `lib/drink_water_web/live/intake_form_component.ex`, replace lines 91-109 (inside the `<.form>`):

```heex
      <.form for={@form} id="intake-form" phx-submit="save" phx-change="validate" phx-target={@myself}>
        <div class="flex gap-2 items-end">
          <fieldset class="fieldset flex-1">
            <legend class="fieldset-legend">{gettext("Custom volume (ml)")}</legend>
            <input
              type="number"
              id="intake-volume"
              name={@form[:volume].name}
              value={@form[:volume].value}
              min="1"
              max="5000"
              class="input input-bordered w-full"
              placeholder={gettext("e.g. 330")}
            />
            <.error :for={error <- @form[:volume].errors}>{translate_error(error)}</.error>
          </fieldset>
          <button type="submit" class="btn btn-primary">{gettext("Log")}</button>
        </div>
      </.form>
```

- [ ] **Step 2: AlarmSettingsComponent — `fieldset` for all form fields**

In `lib/drink_water_web/live/alarm_settings_component.ex`, replace the form section (lines 111-187). Change `<div class="form-control">` + `<label class="label">` to `<fieldset class="fieldset">` + `<legend class="fieldset-legend">`. Change `<div class="flex gap-2">` to `<div class="join">` for action buttons:

```heex
          <.form
            for={@form}
            id="alarm-settings-form"
            phx-submit="save"
            phx-change="validate"
            phx-target={@myself}
            class="space-y-3"
          >
            <fieldset class="fieldset">
              <legend class="fieldset-legend">{gettext("Goal (ml)")}</legend>
              <input
                type="number"
                name={@form[:goal].name}
                value={@form[:goal].value}
                min="50"
                max="10000"
                class="input input-bordered"
              />
              <.error :for={error <- @form[:goal].errors}>{translate_error(error)}</.error>
            </fieldset>

            <fieldset class="fieldset">
              <legend class="fieldset-legend">{gettext("Interval (minutes)")}</legend>
              <input
                type="number"
                name={@form[:interval_minutes].name}
                value={@form[:interval_minutes].value}
                min="15"
                max="240"
                class="input input-bordered"
              />
              <.error :for={error <- @form[:interval_minutes].errors}>
                {translate_error(error)}
              </.error>
            </fieldset>

            <div class="grid grid-cols-2 gap-2">
              <fieldset class="fieldset">
                <legend class="fieldset-legend">{gettext("Start time")}</legend>
                <input
                  type="time"
                  name={@form[:daily_start_time].name}
                  value={@form[:daily_start_time].value}
                  class="input input-bordered"
                />
                <.error :for={error <- @form[:daily_start_time].errors}>
                  {translate_error(error)}
                </.error>
              </fieldset>
              <fieldset class="fieldset">
                <legend class="fieldset-legend">{gettext("End time")}</legend>
                <input
                  type="time"
                  name={@form[:daily_end_time].name}
                  value={@form[:daily_end_time].value}
                  class="input input-bordered"
                />
                <.error :for={error <- @form[:daily_end_time].errors}>
                  {translate_error(error)}
                </.error>
              </fieldset>
            </div>

            <div class="join">
              <button type="submit" class="join-item btn btn-primary btn-sm">
                {gettext("Save")}
              </button>
              <button
                type="button"
                phx-click="cancel-edit"
                phx-target={@myself}
                class="join-item btn btn-ghost btn-sm"
              >
                {gettext("Cancel")}
              </button>
            </div>
          </.form>
```

- [ ] **Step 3: EditIntakeComponent — `fieldset` + `join`**

In `lib/drink_water_web/live/edit_intake_component.ex`, replace the form section (lines 56-101):

```heex
      <h3 class="card-title mb-4">{gettext("Edit Intake")}</h3>
      <.form
        for={@form}
        id="edit-intake-form"
        phx-submit="save"
        phx-change="validate"
        phx-target={@myself}
        class="space-y-3"
      >
        <fieldset class="fieldset">
          <legend class="fieldset-legend">{gettext("Volume (ml)")}</legend>
          <input
            type="number"
            name={@form[:volume].name}
            value={@form[:volume].value}
            min="1"
            max="5000"
            class="input input-bordered"
          />
          <.error :for={error <- @form[:volume].errors}>{translate_error(error)}</.error>
        </fieldset>

        <fieldset class="fieldset">
          <legend class="fieldset-legend">{gettext("Date/Time (UTC)")}</legend>
          <input
            type="datetime-local"
            name={@form[:date_time_utc].name}
            value={format_datetime(@form[:date_time_utc].value)}
            class="input input-bordered"
          />
          <.error :for={error <- @form[:date_time_utc].errors}>{translate_error(error)}</.error>
        </fieldset>

        <div class="join">
          <button type="submit" class="join-item btn btn-primary btn-sm">
            {gettext("Save")}
          </button>
          <button
            type="button"
            phx-click="cancel"
            phx-target={@myself}
            class="join-item btn btn-ghost btn-sm"
          >
            {gettext("Cancel")}
          </button>
        </div>
      </.form>
```

- [ ] **Step 4: Run mix precommit**

Run: `mix precommit`
Expected: All checks pass

- [ ] **Step 5: Commit**

```bash
git add lib/drink_water_web/live/intake_form_component.ex \
        lib/drink_water_web/live/alarm_settings_component.ex \
        lib/drink_water_web/live/edit_intake_component.ex
git commit -m "Step 8i-4: Migrate all forms to daisyUI fieldset + fieldset-legend"
```

---

## Chunk 6: Task 6 — Sub-step 8i-5 (tooltip in weekly chart)

### Task 6: Weekly chart — `tooltip` on bars

**Files:**

- Modify: `lib/drink_water_web/components/dashboard_components.ex`

- [ ] **Step 1: Add `tooltip` wrapper to chart bars**

In `lib/drink_water_web/components/dashboard_components.ex`, update the `weekly_chart` render. Wrap each bar `div` with a `tooltip`:

```elixir
  def weekly_chart(assigns) do
    max_ml =
      Enum.map(assigns.days, fn d -> max(d.total_ml, d.goal) end) |> Enum.max(fn -> 1 end)

    assigns = assign(assigns, max_ml: max_ml)

    ~H"""
    <div class="flex items-end justify-between gap-1 h-32">
      <div :for={day <- @days} class="flex flex-col items-center flex-1">
        <div class="tooltip tooltip-top w-full flex flex-col justify-end h-24"
          data-tip={"#{day.total_ml}ml / #{day.goal}ml"}>
          <div
            class={"rounded-t w-full transition-all duration-500 cursor-pointer #{if @selected_date == day.date, do: "bg-primary", else: "bg-primary/40"}"}
            style={"height: #{day.total_ml / @max_ml * 100}%"}
            phx-click="select-day"
            phx-value-date={day.date}
            phx-target={@target}
          >
          </div>
        </div>
        <span class={"text-xs mt-1 #{if @selected_date == day.date, do: "text-primary font-bold", else: "text-base-content/60"}"}>
          {Calendar.strftime(day.date, "%a")}
        </span>
      </div>
    </div>
    """
  end
```

- [ ] **Step 2: Run mix precommit**

Run: `mix precommit`
Expected: All checks pass

- [ ] **Step 3: Commit**

```bash
git add lib/drink_water_web/components/dashboard_components.ex
git commit -m "Step 8i-5: Add daisyUI tooltip to weekly chart bars"
```

---

## Chunk 7: Task 7 — Sub-step 8i-6 (countdown + timer)

### Task 7: NextAlarmComponent — `countdown` + timer

**Files:**

- Modify: `lib/drink_water_web/live/next_alarm_component.ex`
- Modify: `lib/drink_water_web/live/dashboard_live.ex:16-23`
- Test: `test/drink_water_web/live/next_alarm_component_test.exs`

- [ ] **Step 1: Add countdown calculation to NextAlarmComponent**

Replace `lib/drink_water_web/live/next_alarm_component.ex`:

```elixir
defmodule DrinkWaterWeb.NextAlarmComponent do
  use DrinkWaterWeb, :live_component

  alias DrinkWater.UserManagement

  @impl true
  def update(assigns, socket) do
    alarm_settings = load_alarm_settings(assigns.user_id)
    now = Map.get(assigns, :now, Time.utc_now())
    next_alarm = if alarm_settings, do: calculate_next_alarm(alarm_settings, now), else: nil
    countdown = if next_alarm, do: calculate_countdown(next_alarm, now), else: nil

    {:ok,
     socket
     |> assign(:user_id, assigns.user_id)
     |> assign(:alarm_settings, alarm_settings)
     |> assign(:next_alarm, next_alarm)
     |> assign(:countdown, countdown)}
  end

  defp load_alarm_settings(user_id) do
    case UserManagement.get_alarm_settings_by_user(user_id) do
      {:ok, settings} -> settings
      {:error, :not_found, :alarm_settings} -> nil
    end
  end

  defp calculate_next_alarm(settings, now) do
    start_time = settings.daily_start_time
    end_time = settings.daily_end_time
    interval = settings.interval_minutes

    cond do
      Time.compare(now, start_time) == :lt ->
        start_time

      Time.compare(now, end_time) != :lt ->
        nil

      true ->
        minutes_since_start = Time.diff(now, start_time, :minute)
        intervals_passed = div(minutes_since_start, interval)
        next_minutes = (intervals_passed + 1) * interval
        next_time = Time.add(start_time, next_minutes * 60, :second)

        if Time.compare(next_time, end_time) != :gt, do: next_time, else: nil
    end
  end

  defp calculate_countdown(next_alarm, now) do
    diff_seconds = Time.diff(next_alarm, now, :second)
    diff_seconds = max(diff_seconds, 0)
    hours = div(diff_seconds, 3600)
    minutes = div(rem(diff_seconds, 3600), 60)
    %{hours: hours, minutes: minutes}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h2 class="card-title mb-4">{gettext("Next Alarm")}</h2>
      <%= if @alarm_settings == nil do %>
        <p class="label">{gettext("No alarm configured")}</p>
      <% else %>
        <%= if @next_alarm do %>
          <div class="flex items-center gap-1 font-mono text-2xl">
            <span class="countdown">
              <span style={"--value:#{@countdown.hours};"}></span>
            </span>
            :
            <span class="countdown">
              <span style={"--value:#{@countdown.minutes};"}></span>
            </span>
          </div>
          <p class="label mt-1">
            {gettext("Next at %{time}", time: Calendar.strftime(@next_alarm, "%H:%M"))}
          </p>
          <p class="label text-xs opacity-40">
            {gettext("Every %{minutes} min", minutes: @alarm_settings.interval_minutes)}
            · {Calendar.strftime(@alarm_settings.daily_start_time, "%H:%M")} → {Calendar.strftime(
              @alarm_settings.daily_end_time,
              "%H:%M"
            )}
          </p>
        <% else %>
          <p class="label">{gettext("Done for today!")}</p>
          <p class="label text-xs opacity-40">
            {gettext("Every %{minutes} min", minutes: @alarm_settings.interval_minutes)}
          </p>
        <% end %>
      <% end %>
    </div>
    """
  end
end
```

- [ ] **Step 2: Add `:tick_next_alarm` timer to DashboardLive**

In `lib/drink_water_web/live/dashboard_live.ex`, update `mount/3` to schedule the timer (add after the PubSub subscribe, inside the `connected?` guard):

```elixir
  @impl true
  def mount(_params, _session, socket) do
    user_id = hardcoded_user_id()

    if connected?(socket) do
      Phoenix.PubSub.subscribe(DrinkWater.PubSub, "user:#{user_id}")
      Process.send_after(self(), :tick_next_alarm, 60_000)
    end

    {:ok, assign(socket, page_title: gettext("Hydration Dashboard"), user_id: user_id)}
  end
```

Add `handle_info` for the tick (before the `{:flash, ...}` handler):

```elixir
  # Timer for countdown updates (re-arms every 60 seconds)
  @impl true
  def handle_info(:tick_next_alarm, socket) do
    Process.send_after(self(), :tick_next_alarm, 60_000)

    send_update(DrinkWaterWeb.NextAlarmComponent,
      id: "next-alarm",
      user_id: socket.assigns.user_id
    )

    {:noreply, socket}
  end
```

- [ ] **Step 3: Update NextAlarmComponent tests**

In `test/drink_water_web/live/next_alarm_component_test.exs`, add countdown assertions to the existing "shows next alarm time during active window" test:

```elixir
    test "shows countdown when during active window" do
      user = user_fixture()

      alarm_settings_fixture(user, %{
        goal: 2000,
        interval_minutes: 60,
        daily_start_time: ~T[08:00:00],
        daily_end_time: ~T[20:00:00]
      })

      html = render_component(NextAlarmComponent, id: "test", user_id: user.id, now: ~T[10:30:00])

      # Should show countdown and "Next at 11:00"
      assert html =~ "countdown"
      assert html =~ "Next at 11:00"
    end
```

- [ ] **Step 4: Run mix precommit**

Run: `mix precommit`
Expected: All checks pass

- [ ] **Step 5: Commit**

```bash
git add lib/drink_water_web/live/next_alarm_component.ex \
        lib/drink_water_web/live/dashboard_live.ex \
        test/drink_water_web/live/next_alarm_component_test.exs
git commit -m "Step 8i-6: Add daisyUI countdown with 60s timer for next alarm"
```

---

## Chunk 8: Task 8 — Sub-step 8i-7 (divider between sections)

### Task 8: Dashboard template — `divider` between sections

**Files:**

- Modify: `lib/drink_water_web/live/dashboard_live.html.heex`

- [ ] **Step 1: Add dividers between sections**

In `lib/drink_water_web/live/dashboard_live.html.heex`, replace `mt-4` margins with `divider`:

```heex
  </div>

  <div class="divider"></div>

  <div class="card bg-base-200 shadow-sm">
    <div class="card-body">
      <.live_component
        module={DrinkWaterWeb.HistoryComponent}
        ...
      />
    </div>
  </div>

  <div class="divider"></div>

  <div class="card bg-base-200 shadow-sm">
    <div class="card-body">
      <.live_component
        module={DrinkWaterWeb.WeeklySummaryComponent}
        ...
      />
    </div>
  </div>
```

Remove `mt-4` from the history and weekly summary card divs.

- [ ] **Step 2: Run mix precommit**

Run: `mix precommit`
Expected: All checks pass

- [ ] **Step 3: Commit**

```bash
git add lib/drink_water_web/live/dashboard_live.html.heex
git commit -m "Step 8i-7: Add daisyUI dividers between dashboard sections"
```
