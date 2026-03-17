# Step 8h: Dashboard Enhancements Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add date navigation, edit intake modal, weekly bar click, and success flash to the LiveView dashboard.

**Architecture:** `selected_date` lives in DashboardLive (parent) and is passed to ProgressComponent, HistoryComponent, and WeeklySummaryComponent. Child-to-parent communication uses `send(self(), msg)`. Edit intake uses a modal rendered in the parent template. PubSub guards prevent intake events from disrupting date browsing.

**Tech Stack:** Phoenix LiveView, Phoenix.PubSub, Ecto, daisyUI + Tailwind CSS, Gettext (i18n)

**Spec:** `docs/superpowers/specs/2026-03-17-step8h-dashboard-enhancements-design.md`

---

## File Map

### New files

| File | Responsibility |
|---|---|
| `lib/drink_water_web/live/edit_intake_component.ex` | LiveComponent — modal form for editing an intake |
| `test/drink_water_web/live/edit_intake_component_test.exs` | Edit intake component tests |

### Modified files

| File | Changes |
|---|---|
| `lib/drink_water/hydration_tracking.ex:147-152` | Add broadcast `:intake_updated` to `update_water_intake/2` |
| `lib/drink_water_web/live/dashboard_live.ex` | Add `@selected_date`, `handle_info` for `:select_date`, `:edit_intake`, `:cancel_edit_intake`, `:intake_updated`; conditional PubSub guard; pass `selected_date` in all `send_update` calls |
| `lib/drink_water_web/live/dashboard_live.html.heex` | Pass `selected_date` to components; add conditional modal for edit intake |
| `lib/drink_water_web/live/progress_component.ex` | Accept `selected_date`, use in `daily_progress/3`, dynamic title |
| `lib/drink_water_web/live/history_component.ex` | Accept `selected_date`, nav buttons (← → Today), edit button, dynamic title |
| `lib/drink_water_web/live/weekly_summary_component.ex` | Accept `selected_date`, pass to chart, handle "select-day" event |
| `lib/drink_water_web/live/intake_form_component.ex:38-40,58-59` | Add success flash on save and quick-log |
| `lib/drink_water_web/components/dashboard_components.ex` | `weekly_chart` accepts `selected_date` for bar highlighting |
| `test/drink_water_web/live/dashboard_live_test.exs` | Tests for date nav, bar click, edit, flash |
| `test/drink_water/pubsub_broadcast_test.exs` | Test for `:intake_updated` broadcast |

---

## Chunk 1: Task 1 — Sub-step 8h-4 (Success Flash — simplest, independent)

### Task 1: Success flash on water logging

**Files:**

- Modify: `lib/drink_water_web/live/intake_form_component.ex:38-40,58-59`
- Test: `test/drink_water_web/live/dashboard_live_test.exs`

- [ ] **Step 1: Write failing tests for success flash**

Add to `test/drink_water_web/live/dashboard_live_test.exs`, inside the "log water form" describe:

```elixir
test "shows success flash after logging via form", %{conn: conn} do
  {:ok, view, _html} = live(conn, "/dashboard")

  view
  |> form("#intake-form", intake: %{volume: "250"})
  |> render_submit()

  html = render(view)
  assert html =~ "Water logged!"
end

test "shows success flash after quick-log", %{conn: conn} do
  {:ok, view, _html} = live(conn, "/dashboard")

  view
  |> element("button[phx-click=\"quick-log\"][phx-value-volume=\"500\"]")
  |> render_click()

  html = render(view)
  assert html =~ "Water logged!"
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/drink_water_web/live/dashboard_live_test.exs --only line:XX`
Expected: FAIL — "Water logged!" not in HTML

- [ ] **Step 3: Add success flash to IntakeFormComponent**

In `lib/drink_water_web/live/intake_form_component.ex`, modify the "save" success path (line 38-40):

```elixir
# Replace:
{:ok, _intake} ->
  changeset = WaterIntake.changeset(%WaterIntake{}, %{})
  {:noreply, assign(socket, form: to_form(changeset, as: :intake))}

# With:
{:ok, _intake} ->
  send(self(), {:flash, :info, gettext("Water logged!")})
  changeset = WaterIntake.changeset(%WaterIntake{}, %{})
  {:noreply, assign(socket, form: to_form(changeset, as: :intake))}
```

Modify the "quick-log" success path (line 58-59):

```elixir
# Replace:
{:ok, _intake} ->
  {:noreply, socket}

# With:
{:ok, _intake} ->
  send(self(), {:flash, :info, gettext("Water logged!")})
  {:noreply, socket}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/drink_water_web/live/dashboard_live_test.exs`
Expected: PASS

- [ ] **Step 5: Run mix precommit**

Run: `mix precommit`
Expected: All checks pass

- [ ] **Step 6: Commit**

```bash
git add lib/drink_water_web/live/intake_form_component.ex \
        test/drink_water_web/live/dashboard_live_test.exs
git commit -m "Step 8h-4: Add success flash on water logging (step 8d gap)"
```

---

## Chunk 2: Tasks 2-5 — Sub-step 8h-1 (Date Navigation + PubSub Guard)

### Task 2: Broadcast `:intake_updated` from context

**Files:**

- Modify: `lib/drink_water/hydration_tracking.ex:147-152`
- Test: `test/drink_water/pubsub_broadcast_test.exs`

- [ ] **Step 1: Write failing tests for `:intake_updated` broadcast**

Add to `test/drink_water/pubsub_broadcast_test.exs`, inside the "HydrationTracking broadcasts" describe:

```elixir
test "update_water_intake/2 broadcasts :intake_updated" do
  user = user_fixture()
  intake = water_intake_fixture(user.id)
  Phoenix.PubSub.subscribe(DrinkWater.PubSub, "user:#{user.id}")

  {:ok, _} = HydrationTracking.update_water_intake(intake, %{volume: 999})

  assert_receive :intake_updated
end

test "update_water_intake/2 does not broadcast on failure" do
  user = user_fixture()
  intake = water_intake_fixture(user.id)
  Phoenix.PubSub.subscribe(DrinkWater.PubSub, "user:#{user.id}")

  {:error, _} = HydrationTracking.update_water_intake(intake, %{volume: -1})

  refute_receive :intake_updated
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/drink_water/pubsub_broadcast_test.exs`
Expected: FAIL — `:intake_updated` not received

- [ ] **Step 3: Add broadcast to `update_water_intake/2`**

In `lib/drink_water/hydration_tracking.ex`, replace `update_water_intake/2` (lines 147-152):

```elixir
def update_water_intake(%WaterIntake{} = water_intake, attrs) do
  case water_intake
       |> WaterIntake.changeset(attrs)
       |> Repo.update()
       |> maybe_conflict(:water_intake) do
    {:ok, updated} ->
      broadcast_event(updated.user_id, :intake_updated)
      {:ok, updated}

    error ->
      error
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/drink_water/pubsub_broadcast_test.exs`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/drink_water/hydration_tracking.ex \
        test/drink_water/pubsub_broadcast_test.exs
git commit -m "Step 8h-1a: Add :intake_updated broadcast to update_water_intake/2"
```

### Task 3: ProgressComponent accepts `selected_date`

**Files:**

- Modify: `lib/drink_water_web/live/progress_component.ex`
- Test: `test/drink_water_web/live/dashboard_live_test.exs`

- [ ] **Step 1: Write failing test for dynamic title**

Add to `test/drink_water_web/live/dashboard_live_test.exs`, new describe:

```elixir
describe "date navigation" do
  setup %{user: user} do
    alarm_settings_fixture(user, %{goal: 2000, interval_minutes: 60})
    :ok
  end

  test "title shows date when viewing a past day", %{conn: conn, user: user} do
    yesterday = Date.add(Date.utc_today(), -1)
    water_intake_fixture(user.id, %{
      date_time_utc: DateTime.new!(yesterday, ~T[10:00:00], "Etc/UTC"),
      volume: 300
    })

    {:ok, view, _html} = live(conn, "/dashboard")

    # Click ← to navigate to yesterday
    view
    |> element("button[phx-click=\"nav-prev\"]")
    |> render_click()

    html = render(view)
    assert html =~ Calendar.strftime(yesterday, "%b %d, %Y")
    assert html =~ "300"
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/drink_water_web/live/dashboard_live_test.exs --only line:XX`
Expected: FAIL — no nav-prev button

- [ ] **Step 3: Update ProgressComponent to accept `selected_date`**

Replace `lib/drink_water_web/live/progress_component.ex`:

```elixir
defmodule DrinkWaterWeb.ProgressComponent do
  use DrinkWaterWeb, :live_component

  alias DrinkWater.HydrationTracking

  import DrinkWaterWeb.DashboardComponents, only: [progress_ring: 1]

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
      <%= if @selected_date == Date.utc_today() do %>
        <h2 class="card-title mb-4">{gettext("Daily Progress")}</h2>
      <% else %>
        <h2 class="card-title mb-4">
          {gettext("Progress")} — {Calendar.strftime(@selected_date, "%b %d, %Y")}
        </h2>
      <% end %>
      <.progress_ring
        percentage={@percentage}
        total_ml={@total_ml}
        goal={@goal}
        intake_count={@intake_count}
      />
    </div>
    """
  end
end
```

- [ ] **Step 4: Commit (test still fails — needs HistoryComponent nav buttons)**

```bash
git add lib/drink_water_web/live/progress_component.ex
git commit -m "Step 8h-1b: ProgressComponent accepts selected_date with dynamic title"
```

### Task 4: HistoryComponent with nav buttons, edit button, `selected_date`

**Files:**

- Modify: `lib/drink_water_web/live/history_component.ex`

- [ ] **Step 1: Rewrite HistoryComponent**

Replace `lib/drink_water_web/live/history_component.ex`:

```elixir
defmodule DrinkWaterWeb.HistoryComponent do
  use DrinkWaterWeb, :live_component

  alias DrinkWater.HydrationTracking

  @impl true
  def update(assigns, socket) do
    selected_date =
      assigns[:selected_date] || socket.assigns[:selected_date] || Date.utc_today()

    socket =
      socket
      |> assign(:user_id, assigns.user_id)
      |> assign(:selected_date, selected_date)
      |> load_intakes()

    {:ok, socket}
  end

  defp load_intakes(socket) do
    intakes =
      HydrationTracking.list_daily_intakes(
        socket.assigns.user_id,
        socket.assigns.selected_date
      )

    assign(socket, intakes: intakes)
  end

  @impl true
  def handle_event("nav-prev", _params, socket) do
    new_date = Date.add(socket.assigns.selected_date, -1)
    send(self(), {:select_date, new_date})
    {:noreply, socket}
  end

  @impl true
  def handle_event("nav-next", _params, socket) do
    new_date = Date.add(socket.assigns.selected_date, 1)
    send(self(), {:select_date, new_date})
    {:noreply, socket}
  end

  @impl true
  def handle_event("nav-today", _params, socket) do
    send(self(), {:select_date, Date.utc_today()})
    {:noreply, socket}
  end

  @impl true
  def handle_event("edit", %{"id" => id_str}, socket) do
    case Integer.parse(id_str) do
      {id, ""} -> send(self(), {:edit_intake, id})
      _ -> :noop
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", %{"id" => id_str}, socket) do
    case Integer.parse(id_str) do
      {id, ""} ->
        case HydrationTracking.delete_water_intake_by_id(socket.assigns.user_id, id) do
          {:ok, _} ->
            {:noreply, load_intakes(socket)}

          {:error, :not_found, :water_intake} ->
            send(self(), {:flash, :error, gettext("Intake already removed")})
            {:noreply, load_intakes(socket)}
        end

      _ ->
        {:noreply, socket}
    end
  end

  defp is_today?(date), do: date == Date.utc_today()

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

        <div class="flex gap-1">
          <button
            phx-click="nav-prev"
            phx-target={@myself}
            class="btn btn-ghost btn-xs"
            title={gettext("Previous day")}
          >
            <.icon name="hero-chevron-left" class="w-4 h-4" />
          </button>

          <%= unless @is_today do %>
            <button
              phx-click="nav-today"
              phx-target={@myself}
              class="btn btn-ghost btn-xs"
            >
              {gettext("Today")}
            </button>
          <% end %>

          <button
            phx-click="nav-next"
            phx-target={@myself}
            class={"btn btn-ghost btn-xs #{if @is_today, do: "btn-disabled"}"}
            disabled={@is_today}
            title={gettext("Next day")}
          >
            <.icon name="hero-chevron-right" class="w-4 h-4" />
          </button>
        </div>
      </div>

      <%= if @intakes == [] do %>
        <p class="text-base-content/60">
          <%= if @is_today do %>
            {gettext("No water logged today")}
          <% else %>
            {gettext("No water logged on this day")}
          <% end %>
        </p>
      <% else %>
        <div class="overflow-x-auto">
          <table class="table">
            <thead>
              <tr>
                <th>{gettext("Time")}</th>
                <th>{gettext("Volume")}</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr :for={intake <- @intakes} data-intake-id={intake.id}>
                <td>{Calendar.strftime(intake.date_time_utc, "%H:%M")}</td>
                <td>{intake.volume}ml</td>
                <td class="flex gap-1">
                  <button
                    phx-click="edit"
                    phx-value-id={intake.id}
                    phx-target={@myself}
                    class="btn btn-ghost btn-xs"
                  >
                    <.icon name="hero-pencil-square" class="w-4 h-4" />
                  </button>
                  <button
                    phx-click="delete"
                    phx-value-id={intake.id}
                    phx-target={@myself}
                    class="btn btn-ghost btn-xs text-error"
                  >
                    <.icon name="hero-x-mark" class="w-4 h-4" />
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      <% end %>
    </div>
    """
  end
end
```

- [ ] **Step 2: Commit**

```bash
git add lib/drink_water_web/live/history_component.ex
git commit -m "Step 8h-1c: HistoryComponent with nav buttons, edit button, selected_date"
```

### Task 5: DashboardLive — `selected_date`, `:select_date` handler, PubSub guard

**Files:**

- Modify: `lib/drink_water_web/live/dashboard_live.ex`
- Modify: `lib/drink_water_web/live/dashboard_live.html.heex`

- [ ] **Step 1: Update DashboardLive**

In `lib/drink_water_web/live/dashboard_live.ex`:

Add `selected_date: Date.utc_today()` to the `assign` in `handle_params/3` (line 30-32):

```elixir
{:noreply,
 socket
 |> assign(user: user, goal: goal, selected_date: Date.utc_today())}
```

Add `handle_info` for `:select_date` (before the `{:flash, ...}` handler):

```elixir
@impl true
def handle_info({:select_date, date}, socket) do
  selected_date = date

  send_update(DrinkWaterWeb.ProgressComponent,
    id: "progress",
    user_id: socket.assigns.user.id,
    goal: socket.assigns.goal,
    selected_date: selected_date
  )

  send_update(DrinkWaterWeb.HistoryComponent,
    id: "history",
    user_id: socket.assigns.user.id,
    selected_date: selected_date
  )

  send_update(DrinkWaterWeb.WeeklySummaryComponent,
    id: "weekly-summary",
    user_id: socket.assigns.user.id,
    goal: socket.assigns.goal,
    selected_date: selected_date
  )

  {:noreply, assign(socket, selected_date: selected_date)}
end
```

Replace the `:intake_created`/`:intake_deleted` handler with PubSub guard:

```elixir
@impl true
def handle_info(event, socket)
    when event in [:intake_created, :intake_deleted, :intake_updated] do
  # Always update weekly summary
  send_update(DrinkWaterWeb.WeeklySummaryComponent,
    id: "weekly-summary",
    user_id: socket.assigns.user.id,
    goal: socket.assigns.goal,
    selected_date: socket.assigns.selected_date
  )

  # Only update progress/history if viewing today
  if socket.assigns.selected_date == Date.utc_today() do
    send_update(DrinkWaterWeb.ProgressComponent,
      id: "progress",
      user_id: socket.assigns.user.id,
      goal: socket.assigns.goal,
      selected_date: socket.assigns.selected_date
    )

    send_update(DrinkWaterWeb.HistoryComponent,
      id: "history",
      user_id: socket.assigns.user.id,
      selected_date: socket.assigns.selected_date
    )
  end

  {:noreply, socket}
end
```

Update `:alarm_settings_updated` handler to pass `selected_date` (NOT guarded — goal change affects all days):

```elixir
@impl true
def handle_info(:alarm_settings_updated, socket) do
  goal = load_goal(socket.assigns.user.id)

  send_update(DrinkWaterWeb.ProgressComponent,
    id: "progress",
    user_id: socket.assigns.user.id,
    goal: goal,
    selected_date: socket.assigns.selected_date
  )

  send_update(DrinkWaterWeb.NextAlarmComponent,
    id: "next-alarm",
    user_id: socket.assigns.user.id
  )

  send_update(DrinkWaterWeb.AlarmSettingsComponent,
    id: "alarm-settings",
    user_id: socket.assigns.user.id
  )

  send_update(DrinkWaterWeb.WeeklySummaryComponent,
    id: "weekly-summary",
    user_id: socket.assigns.user.id,
    goal: goal,
    selected_date: socket.assigns.selected_date
  )

  {:noreply, assign(socket, goal: goal)}
end
```

- [ ] **Step 2: Update template to pass `selected_date`**

In `lib/drink_water_web/live/dashboard_live.html.heex`:

Replace the entire Daily Progress card block (lines 10-20) — remove the `<h2>` title
(now rendered inside ProgressComponent) and add `selected_date`:

```heex
<div class="card bg-base-200 shadow-sm">
  <div class="card-body">
    <.live_component
  module={DrinkWaterWeb.ProgressComponent}
  id="progress"
  user_id={@user.id}
  goal={@goal}
  selected_date={@selected_date}
/>

<.live_component
  module={DrinkWaterWeb.HistoryComponent}
  id="history"
  user_id={@user.id}
  selected_date={@selected_date}
/>

<.live_component
  module={DrinkWaterWeb.WeeklySummaryComponent}
  id="weekly-summary"
  user_id={@user.id}
  goal={@goal}
  selected_date={@selected_date}
/>
```

- [ ] **Step 3: Run the date navigation test**

Run: `mix test test/drink_water_web/live/dashboard_live_test.exs`
Expected: PASS — the date navigation test from Task 3 Step 1 now works

- [ ] **Step 4: Add remaining date navigation tests**

Add to the "date navigation" describe in `test/drink_water_web/live/dashboard_live_test.exs`:

```elixir
test "→ button is disabled when viewing today", %{conn: conn} do
  {:ok, _view, html} = live(conn, "/dashboard")

  assert html =~ "btn-disabled"
end

test "Today button is hidden when viewing today", %{conn: conn} do
  {:ok, _view, html} = live(conn, "/dashboard")

  refute html =~ "nav-today"
end

test "PubSub intake_created does not disrupt past day view", %{conn: conn, user: user} do
  {:ok, view, _html} = live(conn, "/dashboard")
  yesterday = Date.add(Date.utc_today(), -1)

  # Navigate to yesterday
  view |> element("button[phx-click=\"nav-prev\"]") |> render_click()
  html = render(view)
  assert html =~ Calendar.strftime(yesterday, "%b %d, %Y")

  # Log water today (triggers :intake_created broadcast)
  water_intake_fixture(user.id, %{date_time_utc: DateTime.utc_now(), volume: 999})

  # Still showing yesterday — not disrupted
  html = render(view)
  assert html =~ Calendar.strftime(yesterday, "%b %d, %Y")
  refute html =~ "999"
end

test "Today button appears and works when viewing past day", %{conn: conn} do
  {:ok, view, _html} = live(conn, "/dashboard")

  # Navigate to yesterday
  view |> element("button[phx-click=\"nav-prev\"]") |> render_click()
  html = render(view)
  assert html =~ "nav-today"

  # Click Today to go back
  view |> element("button[phx-click=\"nav-today\"]") |> render_click()
  html = render(view)
  assert html =~ "Today&#39;s History" or html =~ "Today's History"
end
```

- [ ] **Step 5: Run tests**

Run: `mix test test/drink_water_web/live/dashboard_live_test.exs`
Expected: PASS

- [ ] **Step 6: Run mix precommit**

Run: `mix precommit`
Expected: All checks pass

- [ ] **Step 7: Commit**

```bash
git add lib/drink_water_web/live/dashboard_live.ex \
        lib/drink_water_web/live/dashboard_live.html.heex \
        test/drink_water_web/live/dashboard_live_test.exs
git commit -m "Step 8h-1d: DashboardLive selected_date, nav handler, PubSub guard"
```

---

## Chunk 3: Task 6 — Sub-step 8h-2 (Weekly Bar Click)

### Task 6: WeeklySummaryComponent bar click + highlight

**Files:**

- Modify: `lib/drink_water_web/live/weekly_summary_component.ex`
- Modify: `lib/drink_water_web/components/dashboard_components.ex`
- Test: `test/drink_water_web/live/dashboard_live_test.exs`

- [ ] **Step 1: Write failing tests for bar click**

Add to `test/drink_water_web/live/dashboard_live_test.exs`, new describe:

```elixir
describe "weekly bar click" do
  setup %{user: user} do
    alarm_settings_fixture(user, %{goal: 2000, interval_minutes: 60})

    yesterday = Date.add(Date.utc_today(), -1)
    water_intake_fixture(user.id, %{
      date_time_utc: DateTime.new!(yesterday, ~T[10:00:00], "Etc/UTC"),
      volume: 400
    })

    :ok
  end

  test "clicking a weekly bar navigates to that day", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/dashboard")
    yesterday = Date.add(Date.utc_today(), -1)

    view
    |> element("[phx-click=\"select-day\"][phx-value-date=\"#{yesterday}\"]")
    |> render_click()

    html = render(view)
    assert html =~ Calendar.strftime(yesterday, "%b %d, %Y")
    assert html =~ "400"
  end

  test "selected bar has active styling", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/dashboard")
    yesterday = Date.add(Date.utc_today(), -1)

    view
    |> element("[phx-click=\"select-day\"][phx-value-date=\"#{yesterday}\"]")
    |> render_click()

    html = render(view)
    # Selected bar uses bg-primary, non-selected use bg-primary/40
    assert html =~ "bg-primary\""
    assert html =~ "bg-primary/40"
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/drink_water_web/live/dashboard_live_test.exs --only line:XX`
Expected: FAIL

- [ ] **Step 3: Update `weekly_chart` to accept `selected_date` and add click events**

In `lib/drink_water_web/components/dashboard_components.ex`, replace the `weekly_chart` function:

```elixir
attr :days, :list, required: true
attr :selected_date, :any, default: nil
attr :target, :any, default: nil

def weekly_chart(assigns) do
  max_ml =
    Enum.map(assigns.days, fn d -> max(d.total_ml, d.goal) end) |> Enum.max(fn -> 1 end)

  assigns = assign(assigns, max_ml: max_ml)

  ~H"""
  <div class="flex items-end justify-between gap-1 h-32">
    <div :for={day <- @days} class="flex flex-col items-center flex-1">
      <div class="w-full flex flex-col justify-end h-24">
        <div
          class={"rounded-t w-full transition-all duration-500 cursor-pointer #{if @selected_date == day.date, do: "bg-primary", else: "bg-primary/40"}"}
          style={"height: #{day.total_ml / @max_ml * 100}%"}
          title={"#{day.total_ml}ml / #{day.goal}ml"}
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

- [ ] **Step 4: Update WeeklySummaryComponent to handle `selected_date` and "select-day" event**

Replace `lib/drink_water_web/live/weekly_summary_component.ex`:

```elixir
defmodule DrinkWaterWeb.WeeklySummaryComponent do
  use DrinkWaterWeb, :live_component

  alias DrinkWater.HydrationTracking

  import DrinkWaterWeb.DashboardComponents, only: [weekly_chart: 1]

  @impl true
  def update(assigns, socket) do
    selected_date =
      assigns[:selected_date] || socket.assigns[:selected_date] || Date.utc_today()

    socket =
      socket
      |> assign(:user_id, assigns.user_id)
      |> assign(:goal, assigns.goal)
      |> assign(:selected_date, selected_date)
      |> load_summary()

    {:ok, socket}
  end

  defp load_summary(socket) do
    days =
      HydrationTracking.weekly_summary(
        socket.assigns.user_id,
        Date.utc_today(),
        socket.assigns.goal
      )

    assign(socket, days: days)
  end

  @impl true
  def handle_event("select-day", %{"date" => date_str}, socket) do
    case Date.from_iso8601(date_str) do
      {:ok, date} -> send(self(), {:select_date, date})
      _ -> :noop
    end

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h2 class="card-title mb-4">{gettext("Weekly Summary")}</h2>
      <.weekly_chart days={@days} selected_date={@selected_date} target={@myself} />
    </div>
    """
  end
end
```

- [ ] **Step 5: Run tests**

Run: `mix test test/drink_water_web/live/dashboard_live_test.exs`
Expected: PASS

- [ ] **Step 6: Run mix precommit**

Run: `mix precommit`
Expected: All checks pass

- [ ] **Step 7: Commit**

```bash
git add lib/drink_water_web/live/weekly_summary_component.ex \
        lib/drink_water_web/components/dashboard_components.ex \
        test/drink_water_web/live/dashboard_live_test.exs
git commit -m "Step 8h-2: Weekly bar click navigates to day with highlight"
```

---

## Chunk 4: Tasks 7-8 — Sub-step 8h-3 (Edit Intake Modal)

### Task 7: EditIntakeComponent

**Files:**

- Create: `lib/drink_water_web/live/edit_intake_component.ex`

- [ ] **Step 1: Create EditIntakeComponent**

```elixir
# lib/drink_water_web/live/edit_intake_component.ex
defmodule DrinkWaterWeb.EditIntakeComponent do
  use DrinkWaterWeb, :live_component

  alias DrinkWater.HydrationTracking
  alias DrinkWater.HydrationTracking.WaterIntake

  @impl true
  def update(assigns, socket) do
    changeset = WaterIntake.changeset(assigns.intake, %{})

    {:ok,
     socket
     |> assign(:intake, assigns.intake)
     |> assign(:form, to_form(changeset, as: :intake))}
  end

  @impl true
  def handle_event("validate", %{"intake" => params}, socket) do
    changeset =
      socket.assigns.intake
      |> WaterIntake.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: :intake))}
  end

  @impl true
  def handle_event("save", %{"intake" => params}, socket) do
    case HydrationTracking.update_water_intake(socket.assigns.intake, params) do
      {:ok, _updated} ->
        send(self(), :cancel_edit_intake)
        send(self(), {:flash, :info, gettext("Intake updated!")})
        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: :intake))}
    end
  end

  @impl true
  def handle_event("cancel", _params, socket) do
    send(self(), :cancel_edit_intake)
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h3 class="text-lg font-bold mb-4">{gettext("Edit Intake")}</h3>
      <.form
        for={@form}
        id="edit-intake-form"
        phx-submit="save"
        phx-change="validate"
        phx-target={@myself}
        class="space-y-3"
      >
        <div class="form-control">
          <label class="label">{gettext("Volume (ml)")}</label>
          <input
            type="number"
            name={@form[:volume].name}
            value={@form[:volume].value}
            min="1"
            max="5000"
            class="input input-bordered"
          />
          <.error :for={error <- @form[:volume].errors}>{translate_error(error)}</.error>
        </div>

        <div class="form-control">
          <label class="label">{gettext("Date/Time (UTC)")}</label>
          <input
            type="datetime-local"
            name={@form[:date_time_utc].name}
            value={format_datetime(@form[:date_time_utc].value)}
            class="input input-bordered"
          />
          <.error :for={error <- @form[:date_time_utc].errors}>{translate_error(error)}</.error>
        </div>

        <div class="flex gap-2">
          <button type="submit" class="btn btn-primary btn-sm">
            {gettext("Save")}
          </button>
          <button
            type="button"
            phx-click="cancel"
            phx-target={@myself}
            class="btn btn-ghost btn-sm"
          >
            {gettext("Cancel")}
          </button>
        </div>
      </.form>
    </div>
    """
  end

  defp format_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%dT%H:%M:%S")
  end

  defp format_datetime(value) when is_binary(value), do: value
  defp format_datetime(_), do: ""
end
```

- [ ] **Step 2: Commit**

```bash
git add lib/drink_water_web/live/edit_intake_component.ex
git commit -m "Step 8h-3a: Create EditIntakeComponent with form and validation"
```

### Task 8: Wire edit modal into DashboardLive

**Files:**

- Modify: `lib/drink_water_web/live/dashboard_live.ex`
- Modify: `lib/drink_water_web/live/dashboard_live.html.heex`
- Test: `test/drink_water_web/live/dashboard_live_test.exs`

- [ ] **Step 1: Add alias and `handle_info` handlers in DashboardLive**

In `lib/drink_water_web/live/dashboard_live.ex`:

**First**, add alias at the top (line 5, after `alias DrinkWater.UserManagement`):

```elixir
alias DrinkWater.HydrationTracking
```

**Then**, add `handle_info` handlers before the `{:flash, ...}` handler:

```elixir
@impl true
def handle_info({:edit_intake, intake_id}, socket) do
  case HydrationTracking.get_water_intake(socket.assigns.user.id, intake_id) do
    {:ok, intake} ->
      {:noreply, assign(socket, editing_intake: intake)}

    {:error, :not_found, :water_intake} ->
      {:noreply, put_flash(socket, :error, gettext("Intake not found"))}
  end
end

@impl true
def handle_info(:cancel_edit_intake, socket) do
  {:noreply, assign(socket, editing_intake: nil)}
end
```

Add `editing_intake: nil` to the initial assigns in `handle_params/3`:

```elixir
{:noreply,
 socket
 |> assign(user: user, goal: goal, selected_date: Date.utc_today(), editing_intake: nil)}
```

- [ ] **Step 2: Add modal to template**

In `lib/drink_water_web/live/dashboard_live.html.heex`, add before the closing `</div>`:

```heex
<%= if @editing_intake do %>
  <div class="modal modal-open">
    <div class="modal-box">
      <.live_component
        module={DrinkWaterWeb.EditIntakeComponent}
        id="edit-intake"
        intake={@editing_intake}
      />
    </div>
    <div class="modal-backdrop" phx-click="close-edit-modal"></div>
  </div>
<% end %>
```

Add `handle_event` for backdrop click in DashboardLive:

```elixir
@impl true
def handle_event("close-edit-modal", _params, socket) do
  {:noreply, assign(socket, editing_intake: nil)}
end
```

- [ ] **Step 3: Write tests for edit intake**

Add to `test/drink_water_web/live/dashboard_live_test.exs`, new describe:

```elixir
describe "edit intake" do
  setup %{user: user} do
    alarm_settings_fixture(user, %{goal: 2000, interval_minutes: 60})
    :ok
  end

  test "edit button opens modal with intake data", %{conn: conn, user: user} do
    intake = water_intake_fixture(user.id, %{date_time_utc: DateTime.utc_now(), volume: 300})

    {:ok, view, _html} = live(conn, "/dashboard")

    view
    |> element("[data-intake-id=\"#{intake.id}\"] button[phx-click=\"edit\"]")
    |> render_click()

    html = render(view)
    assert html =~ "Edit Intake"
    assert html =~ "300"
  end

  test "submitting valid edit updates intake and closes modal", %{conn: conn, user: user} do
    intake = water_intake_fixture(user.id, %{date_time_utc: DateTime.utc_now(), volume: 300})

    {:ok, view, _html} = live(conn, "/dashboard")

    view
    |> element("[data-intake-id=\"#{intake.id}\"] button[phx-click=\"edit\"]")
    |> render_click()

    view
    |> form("#edit-intake-form", intake: %{volume: "500"})
    |> render_submit()

    html = render(view)
    refute html =~ "Edit Intake"
    assert html =~ "500"
    assert html =~ "Intake updated!"
  end

  test "submitting invalid edit shows validation errors", %{conn: conn, user: user} do
    intake = water_intake_fixture(user.id, %{date_time_utc: DateTime.utc_now(), volume: 300})

    {:ok, view, _html} = live(conn, "/dashboard")

    view
    |> element("[data-intake-id=\"#{intake.id}\"] button[phx-click=\"edit\"]")
    |> render_click()

    view
    |> form("#edit-intake-form", intake: %{volume: "0"})
    |> render_submit()

    html = render(view)
    assert html =~ "Edit Intake"
    assert html =~ "must be greater than or equal to 1"
  end

  test "cancel closes modal without changes", %{conn: conn, user: user} do
    intake = water_intake_fixture(user.id, %{date_time_utc: DateTime.utc_now(), volume: 300})

    {:ok, view, _html} = live(conn, "/dashboard")

    view
    |> element("[data-intake-id=\"#{intake.id}\"] button[phx-click=\"edit\"]")
    |> render_click()

    assert render(view) =~ "Edit Intake"

    view
    |> element("button[phx-click=\"cancel\"]")
    |> render_click()

    html = render(view)
    refute html =~ "Edit Intake"
    assert html =~ "300"
  end

  test "editing date_time_utc to another day removes intake from current view",
       %{conn: conn, user: user} do
    intake = water_intake_fixture(user.id, %{date_time_utc: DateTime.utc_now(), volume: 300})

    {:ok, view, _html} = live(conn, "/dashboard")

    view
    |> element("[data-intake-id=\"#{intake.id}\"] button[phx-click=\"edit\"]")
    |> render_click()

    yesterday_str = Date.add(Date.utc_today(), -1) |> Date.to_string()

    view
    |> form("#edit-intake-form", intake: %{
      volume: "300",
      date_time_utc: "#{yesterday_str}T10:00:00"
    })
    |> render_submit()

    html = render(view)
    refute html =~ "300"
  end

  test "clicking edit on deleted intake shows error flash", %{conn: conn, user: user} do
    intake = water_intake_fixture(user.id, %{date_time_utc: DateTime.utc_now(), volume: 300})

    {:ok, view, _html} = live(conn, "/dashboard")

    # Delete directly from DB without broadcast
    DrinkWater.Repo.delete!(intake)

    view
    |> element("[data-intake-id=\"#{intake.id}\"] button[phx-click=\"edit\"]")
    |> render_click()

    html = render(view)
    assert html =~ "Intake not found"
    refute html =~ "Edit Intake"
  end
end
```

- [ ] **Step 4: Run tests**

Run: `mix test test/drink_water_web/live/dashboard_live_test.exs`
Expected: PASS

- [ ] **Step 5: Run mix precommit**

Run: `mix precommit`
Expected: All checks pass

- [ ] **Step 6: Commit**

```bash
git add lib/drink_water_web/live/dashboard_live.ex \
        lib/drink_water_web/live/dashboard_live.html.heex \
        test/drink_water_web/live/dashboard_live_test.exs
git commit -m "Step 8h-3: Edit intake modal with validation and real-time updates"
```
