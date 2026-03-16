# Step 8: LiveView Dashboard Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a single-page LiveView dashboard with real-time hydration tracking via PubSub.

**Architecture:** 3-layer split — contexts (business logic + broadcast), live components (state + orchestration), function components (pure UI). DashboardLive subscribes to PubSub once and dispatches to children via `send_update/2`.

**Tech Stack:** Phoenix LiveView, Phoenix.PubSub, Ecto, daisyUI + Tailwind CSS, Gettext (i18n)

**Spec:** `docs/superpowers/specs/2026-03-16-step8-liveview-dashboard-design.md`

---

## File Map

### New files

| File                                                     | Responsibility                                                               |
| -------------------------------------------------------- | ---------------------------------------------------------------------------- |
| `lib/drink_water_web/live/dashboard_live.ex`             | Main LiveView — mount, handle_params, PubSub subscribe, dispatch to children |
| `lib/drink_water_web/live/dashboard_live.html.heex`      | Dashboard template — grid layout with child components                       |
| `lib/drink_water_web/live/progress_component.ex`         | Live component — daily progress ring                                         |
| `lib/drink_water_web/live/history_component.ex`          | Live component — today's intake list with delete                             |
| `lib/drink_water_web/live/intake_form_component.ex`      | Live component — log water form                                              |
| `lib/drink_water_web/live/weekly_summary_component.ex`   | Live component — 7-day bar chart                                             |
| `lib/drink_water_web/live/next_alarm_component.ex`       | Live component — next alarm info                                             |
| `lib/drink_water_web/live/alarm_settings_component.ex`   | Live component — view/edit alarm settings modal                              |
| `lib/drink_water_web/components/dashboard_components.ex` | Function components — progress_ring, intake_card, summary_bar                |
| `test/drink_water_web/live/dashboard_live_test.exs`      | LiveView behavior tests                                                      |
| `test/drink_water/hydration_tracking_dashboard_test.exs` | Context tests for new functions                                              |
| `test/drink_water/pubsub_broadcast_test.exs`             | PubSub broadcast tests                                                       |

### Modified files

| File                                                    | Changes                                                                                                                                                               |
| ------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `lib/drink_water_web/router.ex:35-39`                   | Add `live "/dashboard", DashboardLive` route                                                                                                                          |
| `lib/drink_water/hydration_tracking.ex`                 | Add `daily_progress/3`, `list_daily_intakes/2`, `weekly_summary/3`, `delete_water_intake_by_id/2`; add broadcasts to `create_water_intake/2`, `delete_water_intake/1` |
| `lib/drink_water/user_management.ex:164-168`            | Add broadcast to `update_alarm_settings/2`                                                                                                                            |
| `lib/drink_water_web/components/core_components.ex:299` | Change `defp error(assigns)` to `def error(assigns)` so live components can use `<.error>`                                                                            |

---

## Chunk 1: Task 1 — Sub-step 8a (Base Structure)

### Task 1: DashboardLive route and empty shell

**Files:**

- Modify: `lib/drink_water_web/router.ex:35-39`
- Create: `lib/drink_water_web/live/dashboard_live.ex`
- Create: `lib/drink_water_web/live/dashboard_live.html.heex`
- Test: `test/drink_water_web/live/dashboard_live_test.exs`

- [ ] **Step 0: Make `error/1` public in CoreComponents**

The `error/1` function component in `core_components.ex` is `defp` (private).
Live components in other modules need `<.error>` for form validation. Change
`defp error(assigns)` to `def error(assigns)` on line 299 of
`lib/drink_water_web/components/core_components.ex`.

- [ ] **Step 1: Write the failing test — dashboard page loads**

Note: DashboardLive uses `@hardcoded_user_id 1`. In async tests with a clean
sandbox, the first `user_fixture()` will get id=1. Tests rely on this
ordering — always create the dashboard user first before any other fixtures.

```elixir
# test/drink_water_web/live/dashboard_live_test.exs
defmodule DrinkWaterWeb.DashboardLiveTest do
  use DrinkWaterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import DrinkWater.UserManagementFixtures
  import DrinkWater.HydrationTrackingFixtures

  # DashboardLive uses @hardcoded_user_id 1.
  # The first user_fixture() in a clean sandbox gets id=1.
  # Always create the dashboard user FIRST in each test.

  describe "dashboard page" do
    test "renders dashboard with user name", %{conn: conn} do
      _user = user_fixture(%{first_name: "John", last_name: "Doe"})
      {:ok, _view, html} = live(conn, "/dashboard")

      assert html =~ "Hydration Dashboard"
      assert html =~ "John Doe"
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/drink_water_web/live/dashboard_live_test.exs`
Expected: FAIL — no route matches

- [ ] **Step 3: Add the route**

In `lib/drink_water_web/router.ex`, inside the browser scope:

```elixir
scope "/", DrinkWaterWeb do
  pipe_through :browser

  get "/", PageController, :home
  live "/dashboard", DashboardLive
end
```

- [ ] **Step 4: Create DashboardLive with mount and handle_params**

```elixir
# lib/drink_water_web/live/dashboard_live.ex
defmodule DrinkWaterWeb.DashboardLive do
  use DrinkWaterWeb, :live_view

  alias DrinkWater.UserManagement

  # Hardcoded until auth is implemented (Step 10)
  @hardcoded_user_id 1

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(DrinkWater.PubSub, "user:#{@hardcoded_user_id}")
    end

    {:ok, assign(socket, page_title: gettext("Hydration Dashboard"))}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    case UserManagement.get_user(@hardcoded_user_id) do
      {:ok, user} ->
        {:noreply, assign(socket, user: user)}

      {:error, :not_found, :user} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("User not found"))
         |> redirect(to: ~p"/")}
    end
  end

  @impl true
  def handle_info(_event, socket) do
    # PubSub dispatch — will be expanded in later sub-steps
    {:noreply, socket}
  end
end
```

- [ ] **Step 5: Create the template with placeholder grid**

```heex
<%!-- lib/drink_water_web/live/dashboard_live.html.heex --%>
<div class="container mx-auto px-4 py-6">
  <h1 class="text-2xl font-bold mb-6">
    {gettext("Hydration Dashboard")} — {@user.first_name} {@user.last_name}
  </h1>

  <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
    <div class="card bg-base-200 shadow-sm">
      <div class="card-body">
        <h2 class="card-title">{gettext("Daily Progress")}</h2>
        <p class="text-base-content/60">{gettext("Coming soon...")}</p>
      </div>
    </div>

    <div class="card bg-base-200 shadow-sm">
      <div class="card-body">
        <h2 class="card-title">{gettext("Log Water")}</h2>
        <p class="text-base-content/60">{gettext("Coming soon...")}</p>
      </div>
    </div>

    <div class="card bg-base-200 shadow-sm">
      <div class="card-body">
        <h2 class="card-title">{gettext("Next Alarm")}</h2>
        <p class="text-base-content/60">{gettext("Coming soon...")}</p>
      </div>
    </div>

    <div class="card bg-base-200 shadow-sm">
      <div class="card-body">
        <h2 class="card-title">{gettext("Alarm Settings")}</h2>
        <p class="text-base-content/60">{gettext("Coming soon...")}</p>
      </div>
    </div>
  </div>

  <div class="card bg-base-200 shadow-sm mt-4">
    <div class="card-body">
      <h2 class="card-title">{gettext("Today's History")}</h2>
      <p class="text-base-content/60">{gettext("Coming soon...")}</p>
    </div>
  </div>

  <div class="card bg-base-200 shadow-sm mt-4">
    <div class="card-body">
      <h2 class="card-title">{gettext("Weekly Summary")}</h2>
      <p class="text-base-content/60">{gettext("Coming soon...")}</p>
    </div>
  </div>
</div>
```

- [ ] **Step 6: Run test to verify it passes**

Run: `mix test test/drink_water_web/live/dashboard_live_test.exs`
Expected: PASS

- [ ] **Step 7: Run mix precommit**

Run: `mix precommit`
Expected: All checks pass

- [ ] **Step 8: Commit**

```bash
git add lib/drink_water_web/live/dashboard_live.ex \
        lib/drink_water_web/live/dashboard_live.html.heex \
        lib/drink_water_web/router.ex \
        test/drink_water_web/live/dashboard_live_test.exs
git commit -m "Step 8a: Add DashboardLive with route, layout, and PubSub subscribe"
```

---

## Chunk 2: Tasks 2-3 — Sub-step 8b (Daily Progress)

### Task 2: Context function — daily_progress/3

**Files:**

- Modify: `lib/drink_water/hydration_tracking.ex`
- Test: `test/drink_water/hydration_tracking_dashboard_test.exs`

- [ ] **Step 1: Write failing tests for daily_progress/3**

```elixir
# test/drink_water/hydration_tracking_dashboard_test.exs
defmodule DrinkWater.HydrationTrackingDashboardTest do
  use DrinkWater.DataCase, async: true

  alias DrinkWater.HydrationTracking

  import DrinkWater.UserManagementFixtures
  import DrinkWater.HydrationTrackingFixtures

  describe "daily_progress/3" do
    test "returns zero progress when no intakes exist" do
      user = user_fixture()
      result = HydrationTracking.daily_progress(user.id, Date.utc_today(), 2000)

      assert result == %{total_ml: 0, goal: 2000, percentage: 0.0, intake_count: 0}
    end

    test "returns correct progress with intakes" do
      user = user_fixture()
      today = Date.utc_today()
      now = DateTime.utc_now()

      water_intake_fixture(user.id, %{date_time_utc: now, volume: 500})

      water_intake_fixture(user.id, %{
        date_time_utc: DateTime.add(now, -3600, :second),
        volume: 300
      })

      result = HydrationTracking.daily_progress(user.id, today, 2000)

      assert result == %{total_ml: 800, goal: 2000, percentage: 40.0, intake_count: 2}
    end

    test "caps percentage at 100 when goal is exceeded" do
      user = user_fixture()
      today = Date.utc_today()

      water_intake_fixture(user.id, %{date_time_utc: DateTime.utc_now(), volume: 2500})

      result = HydrationTracking.daily_progress(user.id, today, 2000)

      assert result.total_ml == 2500
      assert result.percentage == 100.0
    end

    test "excludes intakes from other days" do
      user = user_fixture()
      today = Date.utc_today()
      yesterday = Date.add(today, -1)

      water_intake_fixture(user.id, %{
        date_time_utc: DateTime.new!(yesterday, ~T[10:00:00], "Etc/UTC"),
        volume: 500
      })

      water_intake_fixture(user.id, %{date_time_utc: DateTime.utc_now(), volume: 300})

      result = HydrationTracking.daily_progress(user.id, today, 2000)
      assert result.total_ml == 300
      assert result.intake_count == 1
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/drink_water/hydration_tracking_dashboard_test.exs`
Expected: FAIL — `daily_progress/3` undefined

- [ ] **Step 3: Implement daily_progress/3**

Add to `lib/drink_water/hydration_tracking.ex`:

```elixir
@doc """
Returns daily hydration progress for a user.

The `goal` parameter comes from AlarmSettings.goal (integer, in ml).
"""
def daily_progress(user_id, %Date{} = date, goal) when is_integer(goal) and goal > 0 do
  start_of_day = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
  end_of_day = DateTime.new!(Date.add(date, 1), ~T[00:00:00], "Etc/UTC")

  {total_ml, intake_count} =
    WaterIntake
    |> where(user_id: ^user_id)
    |> where([w], w.date_time_utc >= ^start_of_day and w.date_time_utc < ^end_of_day)
    |> select([w], {coalesce(sum(w.volume), 0), count(w.id)})
    |> Repo.one()

  percentage = min(total_ml / goal * 100.0, 100.0) |> Float.round(1)

  %{total_ml: total_ml, goal: goal, percentage: percentage, intake_count: intake_count}
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/drink_water/hydration_tracking_dashboard_test.exs`
Expected: PASS

- [ ] **Step 5: Run mix precommit**

Run: `mix precommit`
Expected: All checks pass

- [ ] **Step 6: Commit**

```bash
git add lib/drink_water/hydration_tracking.ex \
        test/drink_water/hydration_tracking_dashboard_test.exs
git commit -m "Step 8b: Add daily_progress/3 to HydrationTracking context"
```

### Task 3: ProgressComponent + progress ring

**Files:**

- Create: `lib/drink_water_web/live/progress_component.ex`
- Create: `lib/drink_water_web/components/dashboard_components.ex`
- Modify: `lib/drink_water_web/live/dashboard_live.ex`
- Modify: `lib/drink_water_web/live/dashboard_live.html.heex`
- Test: `test/drink_water_web/live/dashboard_live_test.exs`

- [ ] **Step 1: Write failing test — progress card renders**

Add to `test/drink_water_web/live/dashboard_live_test.exs`:

```elixir
import DrinkWater.HydrationTrackingFixtures

describe "daily progress" do
  test "shows 0ml when no intakes logged", %{conn: conn} do
    user = user_fixture()
    alarm_settings_fixture(user, %{goal: 2000})
    {:ok, _view, html} = live(conn, "/dashboard")

    assert html =~ "0ml"
    assert html =~ "2000ml"
    assert html =~ "0%"
  end

  test "shows default goal when no alarm settings exist", %{conn: conn} do
    _user = user_fixture()
    {:ok, _view, html} = live(conn, "/dashboard")

    assert html =~ "2000ml"
  end

  test "shows current progress with intakes", %{conn: conn} do
    user = user_fixture()
    alarm_settings_fixture(user, %{goal: 2000})
    water_intake_fixture(user.id, %{date_time_utc: DateTime.utc_now(), volume: 750})

    {:ok, _view, html} = live(conn, "/dashboard")

    assert html =~ "750ml"
    assert html =~ "2000ml"
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/drink_water_web/live/dashboard_live_test.exs`
Expected: FAIL

- [ ] **Step 3: Create DashboardComponents with progress_ring**

```elixir
# lib/drink_water_web/components/dashboard_components.ex
defmodule DrinkWaterWeb.DashboardComponents do
  @moduledoc """
  Function components for the hydration dashboard.
  Stateless rendering only — zero logic, zero side effects.
  """
  use Phoenix.Component

  use Gettext, backend: DrinkWaterWeb.Gettext

  attr :percentage, :float, required: true
  attr :total_ml, :integer, required: true
  attr :goal, :integer, required: true
  attr :intake_count, :integer, required: true

  def progress_ring(assigns) do
    # SVG circle: circumference = 2 * pi * radius
    # radius = 60, circumference ≈ 377
    assigns = assign(assigns, circumference: 377, radius: 60)

    ~H"""
    <div class="flex flex-col items-center">
      <svg class="w-40 h-40 -rotate-90" viewBox="0 0 140 140">
        <circle
          cx="70"
          cy="70"
          r={@radius}
          fill="none"
          stroke="currentColor"
          stroke-width="12"
          class="text-base-300"
        />
        <circle
          cx="70"
          cy="70"
          r={@radius}
          fill="none"
          stroke="currentColor"
          stroke-width="12"
          stroke-dasharray={@circumference}
          stroke-dashoffset={@circumference - @circumference * @percentage / 100}
          stroke-linecap="round"
          class="text-primary transition-all duration-500"
        />
      </svg>
      <p class="text-2xl font-bold mt-2">{@total_ml}ml / {@goal}ml</p>
      <p class="text-base-content/60">
        {@percentage |> Float.round(0) |> trunc()}%
        — {ngettext("1 intake", "%{count} intakes", @intake_count)}
      </p>
    </div>
    """
  end
end
```

- [ ] **Step 4: Create ProgressComponent**

```elixir
# lib/drink_water_web/live/progress_component.ex
defmodule DrinkWaterWeb.ProgressComponent do
  use DrinkWaterWeb, :live_component

  alias DrinkWater.HydrationTracking

  import DrinkWaterWeb.DashboardComponents, only: [progress_ring: 1]

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(:user_id, assigns.user_id)
      |> assign(:goal, assigns.goal)
      |> load_progress()

    {:ok, socket}
  end

  defp load_progress(socket) do
    progress =
      HydrationTracking.daily_progress(
        socket.assigns.user_id,
        Date.utc_today(),
        socket.assigns.goal
      )

    assign(socket, progress)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
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

- [ ] **Step 5: Wire up DashboardLive to load goal and render ProgressComponent**

Update `lib/drink_water_web/live/dashboard_live.ex` `handle_params/3`:

```elixir
@default_goal 2000

@impl true
def handle_params(_params, _uri, socket) do
  with {:ok, user} <- UserManagement.get_user(@hardcoded_user_id) do
    goal = load_goal(user.id)

    {:noreply,
     socket
     |> assign(user: user, goal: goal)}
  else
    {:error, :not_found, :user} ->
      {:noreply,
       socket
       |> put_flash(:error, gettext("User not found"))
       |> redirect(to: ~p"/")}
  end
end

defp load_goal(user_id) do
  case UserManagement.get_alarm_settings_by_user(user_id) do
    {:ok, settings} -> settings.goal
    {:error, :not_found, :alarm_settings} -> @default_goal
  end
end
```

Update the template `lib/drink_water_web/live/dashboard_live.html.heex` — replace the "Daily Progress" placeholder card:

```heex
<.live_component
  module={DrinkWaterWeb.ProgressComponent}
  id="progress"
  user_id={@user.id}
  goal={@goal}
/>
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `mix test test/drink_water_web/live/dashboard_live_test.exs`
Expected: PASS

- [ ] **Step 7: Run mix precommit**

Run: `mix precommit`
Expected: All checks pass

- [ ] **Step 8: Commit**

```bash
git add lib/drink_water_web/live/progress_component.ex \
        lib/drink_water_web/components/dashboard_components.ex \
        lib/drink_water_web/live/dashboard_live.ex \
        lib/drink_water_web/live/dashboard_live.html.heex \
        test/drink_water_web/live/dashboard_live_test.exs
git commit -m "Step 8b: Add ProgressComponent with SVG progress ring"
```

---

## Chunk 3: Tasks 4-5 — Sub-step 8c (Today's History)

### Task 4: Context functions — list_daily_intakes/2 and delete_water_intake_by_id/2

**Files:**

- Modify: `lib/drink_water/hydration_tracking.ex`
- Test: `test/drink_water/hydration_tracking_dashboard_test.exs`

- [ ] **Step 1: Write failing tests for list_daily_intakes/2**

Add to `test/drink_water/hydration_tracking_dashboard_test.exs`:

```elixir
describe "list_daily_intakes/2" do
  test "returns empty list when no intakes" do
    user = user_fixture()
    assert [] = HydrationTracking.list_daily_intakes(user.id, Date.utc_today())
  end

  test "returns intakes ordered by time desc" do
    user = user_fixture()
    now = DateTime.utc_now()
    earlier = DateTime.add(now, -3600, :second)

    water_intake_fixture(user.id, %{date_time_utc: earlier, volume: 200})
    water_intake_fixture(user.id, %{date_time_utc: now, volume: 500})

    intakes = HydrationTracking.list_daily_intakes(user.id, Date.utc_today())
    assert length(intakes) == 2
    assert hd(intakes).volume == 500
    assert List.last(intakes).volume == 200
  end

  test "excludes intakes from other days" do
    user = user_fixture()
    yesterday = Date.add(Date.utc_today(), -1)

    water_intake_fixture(user.id, %{
      date_time_utc: DateTime.new!(yesterday, ~T[10:00:00], "Etc/UTC"),
      volume: 300
    })

    water_intake_fixture(user.id, %{date_time_utc: DateTime.utc_now(), volume: 500})

    intakes = HydrationTracking.list_daily_intakes(user.id, Date.utc_today())
    assert length(intakes) == 1
    assert hd(intakes).volume == 500
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/drink_water/hydration_tracking_dashboard_test.exs`
Expected: FAIL — `list_daily_intakes/2` undefined

- [ ] **Step 3: Implement list_daily_intakes/2**

Add to `lib/drink_water/hydration_tracking.ex`:

```elixir
@doc """
Returns all water intakes for a user on a given date, ordered by time desc.
No pagination — returns the full list for dashboard display.
"""
def list_daily_intakes(user_id, %Date{} = date) do
  start_of_day = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
  end_of_day = DateTime.new!(Date.add(date, 1), ~T[00:00:00], "Etc/UTC")

  WaterIntake
  |> where(user_id: ^user_id)
  |> where([w], w.date_time_utc >= ^start_of_day and w.date_time_utc < ^end_of_day)
  |> order_by([w], desc: w.date_time_utc)
  |> Repo.all()
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/drink_water/hydration_tracking_dashboard_test.exs`
Expected: PASS (list_daily_intakes tests pass, delete_water_intake_by_id tests still fail)

- [ ] **Step 5: Write failing tests for delete_water_intake_by_id/2**

Add to `test/drink_water/hydration_tracking_dashboard_test.exs`:

```elixir
describe "delete_water_intake_by_id/2" do
  test "deletes an existing intake" do
    user = user_fixture()
    intake = water_intake_fixture(user.id)

    assert {:ok, deleted} = HydrationTracking.delete_water_intake_by_id(user.id, intake.id)
    assert deleted.id == intake.id

    assert {:error, :not_found, :water_intake} =
             HydrationTracking.get_water_intake(user.id, intake.id)
  end

  test "returns error for nonexistent intake" do
    user = user_fixture()

    assert {:error, :not_found, :water_intake} =
             HydrationTracking.delete_water_intake_by_id(user.id, 0)
  end

  test "returns error for intake belonging to another user" do
    user1 = user_fixture()
    user2 = user_fixture()
    intake = water_intake_fixture(user1.id)

    assert {:error, :not_found, :water_intake} =
             HydrationTracking.delete_water_intake_by_id(user2.id, intake.id)
  end
end
```

- [ ] **Step 6: Run tests to verify they fail**

Run: `mix test test/drink_water/hydration_tracking_dashboard_test.exs`
Expected: FAIL — `delete_water_intake_by_id/2` undefined

- [ ] **Step 7: Implement delete_water_intake_by_id/2**

Add to `lib/drink_water/hydration_tracking.ex`:

```elixir
@doc """
Deletes a water intake by user_id and intake id.
Independent implementation — does not delegate to delete_water_intake/1
to avoid double broadcasts.
"""
def delete_water_intake_by_id(user_id, intake_id) do
  case get_water_intake(user_id, intake_id) do
    {:ok, intake} -> Repo.delete(intake)
    error -> error
  end
end
```

- [ ] **Step 8: Run tests to verify they pass**

Run: `mix test test/drink_water/hydration_tracking_dashboard_test.exs`
Expected: PASS

- [ ] **Step 9: Run mix precommit**

Run: `mix precommit`
Expected: All checks pass

- [ ] **Step 10: Commit**

```bash
git add lib/drink_water/hydration_tracking.ex \
        test/drink_water/hydration_tracking_dashboard_test.exs
git commit -m "Step 8c: Add list_daily_intakes/2 and delete_water_intake_by_id/2"
```

### Task 5: HistoryComponent + PubSub broadcast for :intake_deleted

**Files:**

- Modify: `lib/drink_water/hydration_tracking.ex` (add broadcast)
- Create: `lib/drink_water_web/live/history_component.ex`
- Modify: `lib/drink_water_web/components/dashboard_components.ex`
- Modify: `lib/drink_water_web/live/dashboard_live.ex`
- Modify: `lib/drink_water_web/live/dashboard_live.html.heex`
- Test: `test/drink_water/pubsub_broadcast_test.exs`
- Test: `test/drink_water_web/live/dashboard_live_test.exs`

- [ ] **Step 1: Write failing test — delete_water_intake broadcasts**

```elixir
# test/drink_water/pubsub_broadcast_test.exs
defmodule DrinkWater.PubSubBroadcastTest do
  use DrinkWater.DataCase, async: true

  import DrinkWater.UserManagementFixtures
  import DrinkWater.HydrationTrackingFixtures

  alias DrinkWater.HydrationTracking

  describe "HydrationTracking broadcasts" do
    test "delete_water_intake/1 broadcasts :intake_deleted" do
      user = user_fixture()
      intake = water_intake_fixture(user.id)
      Phoenix.PubSub.subscribe(DrinkWater.PubSub, "user:#{user.id}")

      {:ok, _} = HydrationTracking.delete_water_intake(intake)

      assert_receive :intake_deleted
    end

    test "delete_water_intake_by_id/2 broadcasts :intake_deleted" do
      user = user_fixture()
      intake = water_intake_fixture(user.id)
      Phoenix.PubSub.subscribe(DrinkWater.PubSub, "user:#{user.id}")

      {:ok, _} = HydrationTracking.delete_water_intake_by_id(user.id, intake.id)

      assert_receive :intake_deleted
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/drink_water/pubsub_broadcast_test.exs`
Expected: FAIL — no message received

- [ ] **Step 3: Add broadcasts to delete functions**

Update `lib/drink_water/hydration_tracking.ex`:

```elixir
def delete_water_intake(%WaterIntake{} = water_intake) do
  case Repo.delete(water_intake) do
    {:ok, deleted} ->
      broadcast_event(deleted.user_id, :intake_deleted)
      {:ok, deleted}

    error ->
      error
  end
end

def delete_water_intake_by_id(user_id, intake_id) do
  with {:ok, intake} <- get_water_intake(user_id, intake_id),
       {:ok, deleted} <- Repo.delete(intake) do
    broadcast_event(user_id, :intake_deleted)
    {:ok, deleted}
  end
end

defp broadcast_event(user_id, event) do
  Phoenix.PubSub.broadcast(DrinkWater.PubSub, "user:#{user_id}", event)
end
```

- [ ] **Step 4: Run broadcast tests to verify they pass**

Run: `mix test test/drink_water/pubsub_broadcast_test.exs`
Expected: PASS

- [ ] **Step 5: Write failing LiveView test — history shows intakes and delete works**

Add to `test/drink_water_web/live/dashboard_live_test.exs`:

```elixir
describe "today's history" do
  test "shows today's intakes", %{conn: conn} do
    user = user_fixture()
    alarm_settings_fixture(user)
    water_intake_fixture(user.id, %{date_time_utc: DateTime.utc_now(), volume: 250})

    {:ok, _view, html} = live(conn, "/dashboard")

    assert html =~ "250"
  end

  test "shows empty state when no intakes", %{conn: conn} do
    user = user_fixture()
    alarm_settings_fixture(user)

    {:ok, _view, html} = live(conn, "/dashboard")

    assert html =~ gettext("No water logged today")
  end

  test "deleting an intake removes it from the list", %{conn: conn} do
    user = user_fixture()
    alarm_settings_fixture(user)
    intake = water_intake_fixture(user.id, %{date_time_utc: DateTime.utc_now(), volume: 350})

    {:ok, view, _html} = live(conn, "/dashboard")

    view
    |> element("[data-intake-id=\"#{intake.id}\"] button[phx-click=\"delete\"]")
    |> render_click()

    refute render(view) =~ "350"
  end
end
```

- [ ] **Step 6: Create HistoryComponent**

```elixir
# lib/drink_water_web/live/history_component.ex
defmodule DrinkWaterWeb.HistoryComponent do
  use DrinkWaterWeb, :live_component

  alias DrinkWater.HydrationTracking

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(:user_id, assigns.user_id)
      |> load_intakes()

    {:ok, socket}
  end

  defp load_intakes(socket) do
    intakes = HydrationTracking.list_daily_intakes(socket.assigns.user_id, Date.utc_today())
    assign(socket, intakes: intakes)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    id = String.to_integer(id)

    case HydrationTracking.delete_water_intake_by_id(socket.assigns.user_id, id) do
      {:ok, _} ->
        {:noreply, load_intakes(socket)}

      {:error, :not_found, :water_intake} ->
        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h2 class="card-title mb-4">{gettext("Today's History")}</h2>
      <%= if @intakes == [] do %>
        <p class="text-base-content/60">{gettext("No water logged today")}</p>
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
                <td>
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

- [ ] **Step 7: Wire up DashboardLive — add HistoryComponent to template and PubSub dispatch**

Update `lib/drink_water_web/live/dashboard_live.html.heex` — replace "Today's History" placeholder:

```heex
<div class="card bg-base-200 shadow-sm mt-4">
  <div class="card-body">
    <.live_component
      module={DrinkWaterWeb.HistoryComponent}
      id="history"
      user_id={@user.id}
    />
  </div>
</div>
```

Update `lib/drink_water_web/live/dashboard_live.ex` `handle_info`:

```elixir
@impl true
def handle_info(:intake_deleted, socket) do
  send_update(DrinkWaterWeb.ProgressComponent, id: "progress", user_id: socket.assigns.user.id, goal: socket.assigns.goal)
  send_update(DrinkWaterWeb.HistoryComponent, id: "history", user_id: socket.assigns.user.id)
  {:noreply, socket}
end

def handle_info(_event, socket) do
  {:noreply, socket}
end
```

- [ ] **Step 8: Run tests to verify they pass**

Run: `mix test test/drink_water_web/live/dashboard_live_test.exs`
Expected: PASS

- [ ] **Step 9: Run mix precommit**

Run: `mix precommit`
Expected: All checks pass

- [ ] **Step 10: Commit**

```bash
git add lib/drink_water/hydration_tracking.ex \
        lib/drink_water_web/live/history_component.ex \
        lib/drink_water_web/live/dashboard_live.ex \
        lib/drink_water_web/live/dashboard_live.html.heex \
        test/drink_water/pubsub_broadcast_test.exs \
        test/drink_water_web/live/dashboard_live_test.exs
git commit -m "Step 8c: Add HistoryComponent with delete and :intake_deleted broadcast"
```

---

## Chunk 4: Task 6 — Sub-step 8d (Log Water)

### Task 6: IntakeFormComponent + :intake_created broadcast

**Files:**

- Modify: `lib/drink_water/hydration_tracking.ex` (add broadcast to create)
- Create: `lib/drink_water_web/live/intake_form_component.ex`
- Modify: `lib/drink_water_web/live/dashboard_live.ex`
- Modify: `lib/drink_water_web/live/dashboard_live.html.heex`
- Test: `test/drink_water/pubsub_broadcast_test.exs`
- Test: `test/drink_water_web/live/dashboard_live_test.exs`

- [ ] **Step 1: Write failing test — create broadcasts :intake_created**

Add to `test/drink_water/pubsub_broadcast_test.exs`:

```elixir
test "create_water_intake/2 broadcasts :intake_created" do
  user = user_fixture()
  Phoenix.PubSub.subscribe(DrinkWater.PubSub, "user:#{user.id}")

  {:ok, _} =
    HydrationTracking.create_water_intake(user.id, %{
      date_time_utc: DateTime.utc_now(),
      volume: 250,
      volume_unit: :ml
    })

  assert_receive :intake_created
end

test "create_water_intake/2 does not broadcast on failure" do
  user = user_fixture()
  Phoenix.PubSub.subscribe(DrinkWater.PubSub, "user:#{user.id}")

  {:error, _} = HydrationTracking.create_water_intake(user.id, %{})

  refute_receive :intake_created
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/drink_water/pubsub_broadcast_test.exs`
Expected: FAIL on the new create test

- [ ] **Step 3: Add broadcast to create_water_intake/2**

Update `lib/drink_water/hydration_tracking.ex`:

```elixir
def create_water_intake(user_id, attrs) do
  result =
    %WaterIntake{user_id: user_id}
    |> WaterIntake.changeset(attrs)
    |> Repo.insert()
    |> maybe_conflict(:water_intake)

  case result do
    {:ok, intake} ->
      broadcast_event(intake.user_id, :intake_created)
      {:ok, intake}

    error ->
      error
  end
end
```

- [ ] **Step 4: Run broadcast tests to verify they pass**

Run: `mix test test/drink_water/pubsub_broadcast_test.exs`
Expected: PASS

- [ ] **Step 5: Write failing LiveView tests — form submission**

Add to `test/drink_water_web/live/dashboard_live_test.exs`:

```elixir
describe "log water form" do
  test "submitting valid volume logs an intake", %{conn: conn} do
    user = user_fixture()
    alarm_settings_fixture(user, %{goal: 2000})

    {:ok, view, _html} = live(conn, "/dashboard")

    view
    |> form("#intake-form", intake: %{volume: "250"})
    |> render_submit()

    html = render(view)
    assert html =~ "250"
  end

  test "quick button logs preset volume", %{conn: conn} do
    user = user_fixture()
    alarm_settings_fixture(user, %{goal: 2000})

    {:ok, view, _html} = live(conn, "/dashboard")

    view
    |> element("button[phx-click=\"quick-log\"][phx-value-volume=\"500\"]")
    |> render_click()

    html = render(view)
    assert html =~ "500"
  end

  test "shows error for invalid volume", %{conn: conn} do
    user = user_fixture()
    alarm_settings_fixture(user, %{goal: 2000})

    {:ok, view, _html} = live(conn, "/dashboard")

    view
    |> form("#intake-form", intake: %{volume: "0"})
    |> render_submit()

    html = render(view)
    assert html =~ "must be greater than or equal to 1"
  end

  test "progress updates after logging water", %{conn: conn} do
    user = user_fixture()
    alarm_settings_fixture(user, %{goal: 2000})

    {:ok, view, _html} = live(conn, "/dashboard")

    view
    |> form("#intake-form", intake: %{volume: "500"})
    |> render_submit()

    html = render(view)
    # Progress should show 500ml / 2000ml
    assert html =~ "500ml"
    assert html =~ "2000ml"
  end
end
```

- [ ] **Step 6: Create IntakeFormComponent**

```elixir
# lib/drink_water_web/live/intake_form_component.ex
defmodule DrinkWaterWeb.IntakeFormComponent do
  use DrinkWaterWeb, :live_component

  alias DrinkWater.HydrationTracking
  alias DrinkWater.HydrationTracking.WaterIntake

  @quick_volumes [150, 250, 500]

  @impl true
  def update(assigns, socket) do
    changeset = WaterIntake.changeset(%WaterIntake{}, %{})

    {:ok,
     socket
     |> assign(:user_id, assigns.user_id)
     |> assign(:quick_volumes, @quick_volumes)
     |> assign(:form, to_form(changeset, as: :intake))}
  end

  @impl true
  def handle_event("validate", %{"intake" => params}, socket) do
    changeset =
      %WaterIntake{}
      |> WaterIntake.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: :intake))}
  end

  @impl true
  def handle_event("save", %{"intake" => params}, socket) do
    attrs =
      params
      |> Map.put("date_time_utc", DateTime.utc_now())
      |> Map.put("volume_unit", "ml")

    case HydrationTracking.create_water_intake(socket.assigns.user_id, attrs) do
      {:ok, _intake} ->
        changeset = WaterIntake.changeset(%WaterIntake{}, %{})

        changeset = WaterIntake.changeset(%WaterIntake{}, %{})

        {:noreply, assign(socket, form: to_form(changeset, as: :intake))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: :intake))}
    end
  end

  @impl true
  def handle_event("quick-log", %{"volume" => volume}, socket) do
    attrs = %{
      date_time_utc: DateTime.utc_now(),
      volume: String.to_integer(volume),
      volume_unit: :ml
    }

    case HydrationTracking.create_water_intake(socket.assigns.user_id, attrs) do
      {:ok, _intake} ->
        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h2 class="card-title mb-4">{gettext("Log Water")}</h2>

      <div class="flex gap-2 mb-4">
        <button
          :for={volume <- @quick_volumes}
          phx-click="quick-log"
          phx-value-volume={volume}
          phx-target={@myself}
          class="btn btn-primary btn-sm"
        >
          {volume}ml
        </button>
      </div>

      <.form for={@form} id="intake-form" phx-submit="save" phx-change="validate" phx-target={@myself}>
        <div class="flex gap-2 items-end">
          <div class="form-control flex-1">
            <label class="label" for="intake-volume">{gettext("Custom volume (ml)")}</label>
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
            <.error :for={{msg, _opts} <- @form[:volume].errors}>{msg}</.error>
          </div>
          <button type="submit" class="btn btn-primary">{gettext("Log")}</button>
        </div>
      </.form>
    </div>
    """
  end
end
```

- [ ] **Step 7: Wire up DashboardLive — add IntakeFormComponent and :intake_created dispatch**

Update template — replace "Log Water" placeholder:

```heex
<div class="card bg-base-200 shadow-sm">
  <div class="card-body">
    <.live_component
      module={DrinkWaterWeb.IntakeFormComponent}
      id="intake-form-component"
      user_id={@user.id}
    />
  </div>
</div>
```

Update `handle_info` in DashboardLive:

```elixir
@impl true
def handle_info(:intake_created, socket) do
  send_update(DrinkWaterWeb.ProgressComponent, id: "progress", user_id: socket.assigns.user.id, goal: socket.assigns.goal)
  send_update(DrinkWaterWeb.HistoryComponent, id: "history", user_id: socket.assigns.user.id)
  {:noreply, socket}
end

def handle_info(:intake_deleted, socket) do
  send_update(DrinkWaterWeb.ProgressComponent, id: "progress", user_id: socket.assigns.user.id, goal: socket.assigns.goal)
  send_update(DrinkWaterWeb.HistoryComponent, id: "history", user_id: socket.assigns.user.id)
  {:noreply, socket}
end

def handle_info(_event, socket) do
  {:noreply, socket}
end
```

- [ ] **Step 8: Run tests to verify they pass**

Run: `mix test test/drink_water_web/live/dashboard_live_test.exs`
Expected: PASS

- [ ] **Step 9: Run mix precommit**

Run: `mix precommit`
Expected: All checks pass

- [ ] **Step 10: Commit**

```bash
git add lib/drink_water/hydration_tracking.ex \
        lib/drink_water_web/live/intake_form_component.ex \
        lib/drink_water_web/live/dashboard_live.ex \
        lib/drink_water_web/live/dashboard_live.html.heex \
        test/drink_water/pubsub_broadcast_test.exs \
        test/drink_water_web/live/dashboard_live_test.exs
git commit -m "Step 8d: Add IntakeFormComponent with :intake_created broadcast and real-time updates"
```

---

## Chunk 5: Task 7 — Sub-step 8e (Weekly Summary)

### Task 7: weekly_summary/3 + WeeklySummaryComponent

**Files:**

- Modify: `lib/drink_water/hydration_tracking.ex`
- Create: `lib/drink_water_web/live/weekly_summary_component.ex`
- Modify: `lib/drink_water_web/components/dashboard_components.ex`
- Modify: `lib/drink_water_web/live/dashboard_live.ex`
- Modify: `lib/drink_water_web/live/dashboard_live.html.heex`
- Test: `test/drink_water/hydration_tracking_dashboard_test.exs`
- Test: `test/drink_water_web/live/dashboard_live_test.exs`

- [ ] **Step 1: Write failing tests for weekly_summary/3**

Add to `test/drink_water/hydration_tracking_dashboard_test.exs`:

```elixir
describe "weekly_summary/3" do
  test "returns 7 days ending on the given date" do
    user = user_fixture()
    today = Date.utc_today()

    result = HydrationTracking.weekly_summary(user.id, today, 2000)

    assert length(result) == 7
    assert hd(result).date == Date.add(today, -6)
    assert List.last(result).date == today
  end

  test "returns total_ml 0 for days with no intakes" do
    user = user_fixture()
    today = Date.utc_today()

    result = HydrationTracking.weekly_summary(user.id, today, 2000)

    assert Enum.all?(result, fn day -> day.total_ml == 0 end)
  end

  test "includes goal in each day entry" do
    user = user_fixture()
    today = Date.utc_today()

    result = HydrationTracking.weekly_summary(user.id, today, 1500)

    assert Enum.all?(result, fn day -> day.goal == 1500 end)
  end

  test "sums volumes per day correctly" do
    user = user_fixture()
    today = Date.utc_today()
    now = DateTime.utc_now()

    water_intake_fixture(user.id, %{date_time_utc: now, volume: 300})
    water_intake_fixture(user.id, %{date_time_utc: DateTime.add(now, -60, :second), volume: 200})

    result = HydrationTracking.weekly_summary(user.id, today, 2000)

    today_entry = Enum.find(result, fn day -> day.date == today end)
    assert today_entry.total_ml == 500
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/drink_water/hydration_tracking_dashboard_test.exs`
Expected: FAIL — `weekly_summary/3` undefined

- [ ] **Step 3: Implement weekly_summary/3**

Add to `lib/drink_water/hydration_tracking.ex`:

```elixir
@doc """
Returns a 7-day hydration summary ending on `end_date` (inclusive).
Days with no intakes appear with total_ml: 0.
A single `goal` value is applied to all days.
"""
def weekly_summary(user_id, %Date{} = end_date, goal) when is_integer(goal) and goal > 0 do
  start_date = Date.add(end_date, -6)
  start_dt = DateTime.new!(start_date, ~T[00:00:00], "Etc/UTC")
  end_dt = DateTime.new!(Date.add(end_date, 1), ~T[00:00:00], "Etc/UTC")

  daily_totals =
    WaterIntake
    |> where(user_id: ^user_id)
    |> where([w], w.date_time_utc >= ^start_dt and w.date_time_utc < ^end_dt)
    |> group_by([w], fragment("?::date", w.date_time_utc))
    |> select([w], {fragment("?::date", w.date_time_utc), sum(w.volume)})
    |> Repo.all()
    |> Map.new()

  Date.range(start_date, end_date)
  |> Enum.map(fn date ->
    %{date: date, total_ml: Map.get(daily_totals, date, 0), goal: goal}
  end)
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/drink_water/hydration_tracking_dashboard_test.exs`
Expected: PASS

- [ ] **Step 5: Write failing LiveView test — weekly summary renders**

Add to `test/drink_water_web/live/dashboard_live_test.exs`:

```elixir
describe "weekly summary" do
  test "shows 7 day bars", %{conn: conn} do
    user = user_fixture()
    alarm_settings_fixture(user, %{goal: 2000})

    {:ok, _view, html} = live(conn, "/dashboard")

    assert html =~ gettext("Weekly Summary")
    # Should have 7 day labels
    today = Date.utc_today()
    for offset <- -6..0 do
      day = Date.add(today, offset)
      day_abbr = Calendar.strftime(day, "%a")
      assert html =~ day_abbr
    end
  end
end
```

- [ ] **Step 6: Add summary_bar function component to DashboardComponents**

Add to `lib/drink_water_web/components/dashboard_components.ex`:

```elixir
attr :days, :list, required: true

def weekly_chart(assigns) do
  max_ml = Enum.map(assigns.days, fn d -> max(d.total_ml, d.goal) end) |> Enum.max(fn -> 1 end)
  assigns = assign(assigns, max_ml: max_ml)

  ~H"""
  <div class="flex items-end justify-between gap-1 h-32">
    <div :for={day <- @days} class="flex flex-col items-center flex-1">
      <div class="w-full flex flex-col justify-end h-24">
        <div
          class="bg-primary rounded-t w-full transition-all duration-500"
          style={"height: #{day.total_ml / @max_ml * 100}%"}
          title={"#{day.total_ml}ml / #{day.goal}ml"}
        >
        </div>
      </div>
      <span class="text-xs mt-1 text-base-content/60">
        {Calendar.strftime(day.date, "%a")}
      </span>
    </div>
  </div>
  """
end
```

- [ ] **Step 7: Create WeeklySummaryComponent**

```elixir
# lib/drink_water_web/live/weekly_summary_component.ex
defmodule DrinkWaterWeb.WeeklySummaryComponent do
  use DrinkWaterWeb, :live_component

  alias DrinkWater.HydrationTracking

  import DrinkWaterWeb.DashboardComponents, only: [weekly_chart: 1]

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(:user_id, assigns.user_id)
      |> assign(:goal, assigns.goal)
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
  def render(assigns) do
    ~H"""
    <div>
      <h2 class="card-title mb-4">{gettext("Weekly Summary")}</h2>
      <.weekly_chart days={@days} />
    </div>
    """
  end
end
```

- [ ] **Step 8: Wire up template and PubSub dispatch**

Update template — replace "Weekly Summary" placeholder:

```heex
<div class="card bg-base-200 shadow-sm mt-4">
  <div class="card-body">
    <.live_component
      module={DrinkWaterWeb.WeeklySummaryComponent}
      id="weekly-summary"
      user_id={@user.id}
      goal={@goal}
    />
  </div>
</div>
```

Update `handle_info` in DashboardLive — add WeeklySummaryComponent to `:intake_created` and `:intake_deleted` dispatches:

```elixir
send_update(DrinkWaterWeb.WeeklySummaryComponent, id: "weekly-summary", user_id: socket.assigns.user.id, goal: socket.assigns.goal)
```

- [ ] **Step 9: Run tests to verify they pass**

Run: `mix test test/drink_water_web/live/dashboard_live_test.exs`
Expected: PASS

- [ ] **Step 10: Run mix precommit**

Run: `mix precommit`
Expected: All checks pass

- [ ] **Step 11: Commit**

```bash
git add lib/drink_water/hydration_tracking.ex \
        lib/drink_water_web/live/weekly_summary_component.ex \
        lib/drink_water_web/components/dashboard_components.ex \
        lib/drink_water_web/live/dashboard_live.ex \
        lib/drink_water_web/live/dashboard_live.html.heex \
        test/drink_water/hydration_tracking_dashboard_test.exs \
        test/drink_water_web/live/dashboard_live_test.exs
git commit -m "Step 8e: Add weekly_summary/3 and WeeklySummaryComponent with CSS bars"
```

---

## Chunk 6: Task 8 — Sub-step 8f (Next Alarm)

### Task 8: NextAlarmComponent

**Files:**

- Create: `lib/drink_water_web/live/next_alarm_component.ex`
- Modify: `lib/drink_water_web/live/dashboard_live.ex`
- Modify: `lib/drink_water_web/live/dashboard_live.html.heex`
- Test: `test/drink_water_web/live/dashboard_live_test.exs`

- [ ] **Step 1: Write failing test — next alarm shows time info**

Add to `test/drink_water_web/live/dashboard_live_test.exs`:

```elixir
describe "next alarm" do
  test "shows alarm settings info", %{conn: conn} do
    user = user_fixture()

    alarm_settings_fixture(user, %{
      goal: 2000,
      interval_minutes: 60,
      daily_start_time: ~T[08:00:00],
      daily_end_time: ~T[20:00:00]
    })

    {:ok, _view, html} = live(conn, "/dashboard")

    assert html =~ gettext("Next Alarm")
    assert html =~ "60"
  end

  test "shows message when no alarm settings", %{conn: conn} do
    _user = user_fixture()

    {:ok, _view, html} = live(conn, "/dashboard")

    assert html =~ gettext("No alarm configured")
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/drink_water_web/live/dashboard_live_test.exs`
Expected: FAIL — NextAlarmComponent not found

- [ ] **Step 3: Create NextAlarmComponent**

```elixir
# lib/drink_water_web/live/next_alarm_component.ex
defmodule DrinkWaterWeb.NextAlarmComponent do
  use DrinkWaterWeb, :live_component

  alias DrinkWater.UserManagement

  @impl true
  def update(assigns, socket) do
    alarm_settings = load_alarm_settings(assigns.user_id)
    next_alarm = if alarm_settings, do: calculate_next_alarm(alarm_settings), else: nil

    {:ok,
     socket
     |> assign(:user_id, assigns.user_id)
     |> assign(:alarm_settings, alarm_settings)
     |> assign(:next_alarm, next_alarm)}
  end

  defp load_alarm_settings(user_id) do
    case UserManagement.get_alarm_settings_by_user(user_id) do
      {:ok, settings} -> settings
      {:error, :not_found, :alarm_settings} -> nil
    end
  end

  defp calculate_next_alarm(settings) do
    now = Time.utc_now()
    start_time = settings.daily_start_time
    end_time = settings.daily_end_time
    interval = settings.interval_minutes

    cond do
      Time.compare(now, start_time) == :lt ->
        start_time

      Time.compare(now, end_time) != :lt ->
        nil

      true ->
        # Calculate next alarm from start_time + N*interval that is > now
        minutes_since_start = Time.diff(now, start_time, :minute)
        intervals_passed = div(minutes_since_start, interval)
        next_minutes = (intervals_passed + 1) * interval
        next_time = Time.add(start_time, next_minutes * 60, :second)

        if Time.compare(next_time, end_time) != :gt, do: next_time, else: nil
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h2 class="card-title mb-4">{gettext("Next Alarm")}</h2>
      <%= if @alarm_settings == nil do %>
        <p class="text-base-content/60">{gettext("No alarm configured")}</p>
      <% else %>
        <%= if @next_alarm do %>
          <p class="text-xl font-bold">{Calendar.strftime(@next_alarm, "%H:%M")}</p>
          <p class="text-base-content/60">
            {gettext("Every %{minutes} minutes", minutes: @alarm_settings.interval_minutes)}
          </p>
          <p class="text-sm text-base-content/40">
            {Calendar.strftime(@alarm_settings.daily_start_time, "%H:%M")}
            →
            {Calendar.strftime(@alarm_settings.daily_end_time, "%H:%M")}
          </p>
        <% else %>
          <p class="text-base-content/60">{gettext("Done for today!")}</p>
        <% end %>
      <% end %>
    </div>
    """
  end
end
```

- [ ] **Step 4: Wire up template — replace "Next Alarm" placeholder**

```heex
<div class="card bg-base-200 shadow-sm">
  <div class="card-body">
    <.live_component
      module={DrinkWaterWeb.NextAlarmComponent}
      id="next-alarm"
      user_id={@user.id}
    />
  </div>
</div>
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `mix test test/drink_water_web/live/dashboard_live_test.exs --only describe:"next alarm"`
Expected: PASS

- [ ] **Step 6: Run mix precommit**

Run: `mix precommit`
Expected: All checks pass

- [ ] **Step 7: Commit**

```bash
git add lib/drink_water_web/live/next_alarm_component.ex \
        lib/drink_water_web/live/dashboard_live.ex \
        lib/drink_water_web/live/dashboard_live.html.heex \
        test/drink_water_web/live/dashboard_live_test.exs
git commit -m "Step 8f: Add NextAlarmComponent with alarm time calculation"
```

---

## Chunk 7: Task 9 — Sub-step 8g (Edit Alarm Settings)

### Task 9: AlarmSettingsComponent + :alarm_settings_updated broadcast

**Files:**

- Modify: `lib/drink_water/user_management.ex` (add broadcast)
- Create: `lib/drink_water_web/live/alarm_settings_component.ex`
- Modify: `lib/drink_water_web/live/dashboard_live.ex`
- Modify: `lib/drink_water_web/live/dashboard_live.html.heex`
- Test: `test/drink_water/pubsub_broadcast_test.exs`
- Test: `test/drink_water_web/live/dashboard_live_test.exs`

- [ ] **Step 1: Write failing test — update_alarm_settings broadcasts**

Add to `test/drink_water/pubsub_broadcast_test.exs`:

```elixir
alias DrinkWater.UserManagement

describe "UserManagement broadcasts" do
  test "update_alarm_settings/2 broadcasts :alarm_settings_updated" do
    user = user_fixture()
    settings = alarm_settings_fixture(user)
    Phoenix.PubSub.subscribe(DrinkWater.PubSub, "user:#{user.id}")

    {:ok, _} = UserManagement.update_alarm_settings(settings, %{goal: 2500})

    assert_receive :alarm_settings_updated
  end

  test "update_alarm_settings/2 does not broadcast on failure" do
    user = user_fixture()
    settings = alarm_settings_fixture(user)
    Phoenix.PubSub.subscribe(DrinkWater.PubSub, "user:#{user.id}")

    {:error, _} = UserManagement.update_alarm_settings(settings, %{goal: -1})

    refute_receive :alarm_settings_updated
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/drink_water/pubsub_broadcast_test.exs`
Expected: FAIL on UserManagement tests

- [ ] **Step 3: Add broadcast to update_alarm_settings/2**

Update `lib/drink_water/user_management.ex`:

```elixir
def update_alarm_settings(%AlarmSettings{} = alarm_settings, attrs) do
  case alarm_settings
       |> AlarmSettings.changeset(attrs)
       |> Repo.update() do
    {:ok, updated} ->
      Phoenix.PubSub.broadcast(
        DrinkWater.PubSub,
        "user:#{updated.user_id}",
        :alarm_settings_updated
      )

      {:ok, updated}

    error ->
      error
  end
end
```

- [ ] **Step 4: Run broadcast tests to verify they pass**

Run: `mix test test/drink_water/pubsub_broadcast_test.exs`
Expected: PASS

- [ ] **Step 5: Write failing LiveView tests — alarm settings display and edit**

Add to `test/drink_water_web/live/dashboard_live_test.exs`:

```elixir
describe "alarm settings" do
  test "shows current alarm settings", %{conn: conn} do
    user = user_fixture()
    alarm_settings_fixture(user, %{goal: 2000, interval_minutes: 60})

    {:ok, _view, html} = live(conn, "/dashboard")

    assert html =~ "2000"
    assert html =~ "60"
  end

  test "editing alarm settings updates dependent components", %{conn: conn} do
    user = user_fixture()
    alarm_settings_fixture(user, %{goal: 2000, interval_minutes: 60})

    {:ok, view, _html} = live(conn, "/dashboard")

    # Open edit modal
    view
    |> element("button[phx-click=\"edit-settings\"]")
    |> render_click()

    # Submit new settings
    view
    |> form("#alarm-settings-form",
      alarm_settings: %{
        goal: "2500",
        interval_minutes: "45",
        daily_start_time: "08:00",
        daily_end_time: "20:00"
      }
    )
    |> render_submit()

    html = render(view)
    assert html =~ "2500"
    assert html =~ "45"
  end
end
```

- [ ] **Step 6: Create AlarmSettingsComponent**

```elixir
# lib/drink_water_web/live/alarm_settings_component.ex
defmodule DrinkWaterWeb.AlarmSettingsComponent do
  use DrinkWaterWeb, :live_component

  alias DrinkWater.UserManagement
  alias DrinkWater.UserManagement.AlarmSettings

  # Note: The spec mentions a daisyUI modal, but we use an inline toggle
  # (`@editing` boolean) for simplicity. The behavior is equivalent — the
  # form appears in-place when "Edit" is clicked. A modal can be added later
  # if needed without changing the component's logic.

  @impl true
  def update(assigns, socket) do
    alarm_settings = load_alarm_settings(assigns.user_id)

    # Preserve editing state across PubSub-triggered re-renders.
    # Only set editing=false on initial mount (when not already assigned).
    editing = Map.get(socket.assigns, :editing, false)

    {:ok,
     socket
     |> assign(:user_id, assigns.user_id)
     |> assign(:alarm_settings, alarm_settings)
     |> assign(:editing, editing)
     |> assign_form(alarm_settings)}
  end

  defp load_alarm_settings(user_id) do
    case UserManagement.get_alarm_settings_by_user(user_id) do
      {:ok, settings} -> settings
      {:error, :not_found, :alarm_settings} -> nil
    end
  end

  defp assign_form(socket, nil) do
    changeset = AlarmSettings.changeset(%AlarmSettings{}, %{})
    assign(socket, form: to_form(changeset, as: :alarm_settings))
  end

  defp assign_form(socket, settings) do
    changeset = AlarmSettings.changeset(settings, %{})
    assign(socket, form: to_form(changeset, as: :alarm_settings))
  end

  @impl true
  def handle_event("edit-settings", _params, socket) do
    {:noreply, assign(socket, editing: true)}
  end

  @impl true
  def handle_event("cancel-edit", _params, socket) do
    {:noreply, assign(socket, editing: false)}
  end

  @impl true
  def handle_event("validate", %{"alarm_settings" => params}, socket) do
    changeset =
      (socket.assigns.alarm_settings || %AlarmSettings{})
      |> AlarmSettings.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: :alarm_settings))}
  end

  @impl true
  def handle_event("save", %{"alarm_settings" => params}, socket) do
    case UserManagement.update_alarm_settings(socket.assigns.alarm_settings, params) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> assign(alarm_settings: updated, editing: false)
         |> assign_form(updated)
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: :alarm_settings))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h2 class="card-title mb-4">{gettext("Alarm Settings")}</h2>
      <%= if @alarm_settings == nil do %>
        <p class="text-base-content/60">{gettext("No alarm configured")}</p>
      <% else %>
        <%= unless @editing do %>
          <dl class="space-y-1 text-sm">
            <div class="flex justify-between">
              <dt class="text-base-content/60">{gettext("Goal")}</dt>
              <dd class="font-medium">{@alarm_settings.goal}ml</dd>
            </div>
            <div class="flex justify-between">
              <dt class="text-base-content/60">{gettext("Interval")}</dt>
              <dd class="font-medium">{@alarm_settings.interval_minutes} {gettext("min")}</dd>
            </div>
            <div class="flex justify-between">
              <dt class="text-base-content/60">{gettext("Hours")}</dt>
              <dd class="font-medium">
                {Calendar.strftime(@alarm_settings.daily_start_time, "%H:%M")}
                →
                {Calendar.strftime(@alarm_settings.daily_end_time, "%H:%M")}
              </dd>
            </div>
          </dl>
          <button
            phx-click="edit-settings"
            phx-target={@myself}
            class="btn btn-soft btn-sm mt-4"
          >
            {gettext("Edit")}
          </button>
        <% else %>
          <.form
            for={@form}
            id="alarm-settings-form"
            phx-submit="save"
            phx-change="validate"
            phx-target={@myself}
            class="space-y-3"
          >
            <div class="form-control">
              <label class="label">{gettext("Goal (ml)")}</label>
              <input
                type="number"
                name={@form[:goal].name}
                value={@form[:goal].value}
                min="50"
                max="10000"
                class="input input-bordered"
              />
              <.error :for={{msg, _opts} <- @form[:goal].errors}>{msg}</.error>
            </div>

            <div class="form-control">
              <label class="label">{gettext("Interval (minutes)")}</label>
              <input
                type="number"
                name={@form[:interval_minutes].name}
                value={@form[:interval_minutes].value}
                min="15"
                max="240"
                class="input input-bordered"
              />
              <.error :for={{msg, _opts} <- @form[:interval_minutes].errors}>{msg}</.error>
            </div>

            <div class="grid grid-cols-2 gap-2">
              <div class="form-control">
                <label class="label">{gettext("Start time")}</label>
                <input
                  type="time"
                  name={@form[:daily_start_time].name}
                  value={@form[:daily_start_time].value}
                  class="input input-bordered"
                />
                <.error :for={{msg, _opts} <- @form[:daily_start_time].errors}>{msg}</.error>
              </div>
              <div class="form-control">
                <label class="label">{gettext("End time")}</label>
                <input
                  type="time"
                  name={@form[:daily_end_time].name}
                  value={@form[:daily_end_time].value}
                  class="input input-bordered"
                />
                <.error :for={{msg, _opts} <- @form[:daily_end_time].errors}>{msg}</.error>
              </div>
            </div>

            <div class="flex gap-2">
              <button type="submit" class="btn btn-primary btn-sm">{gettext("Save")}</button>
              <button
                type="button"
                phx-click="cancel-edit"
                phx-target={@myself}
                class="btn btn-ghost btn-sm"
              >
                {gettext("Cancel")}
              </button>
            </div>
          </.form>
        <% end %>
      <% end %>
    </div>
    """
  end
end
```

- [ ] **Step 7: Wire up template and PubSub dispatch for :alarm_settings_updated**

Update template — replace "Alarm Settings" placeholder:

```heex
<div class="card bg-base-200 shadow-sm">
  <div class="card-body">
    <.live_component
      module={DrinkWaterWeb.AlarmSettingsComponent}
      id="alarm-settings"
      user_id={@user.id}
    />
  </div>
</div>
```

Add to DashboardLive `handle_info`:

```elixir
@impl true
def handle_info(:alarm_settings_updated, socket) do
  goal = load_goal(socket.assigns.user.id)

  send_update(DrinkWaterWeb.ProgressComponent, id: "progress", user_id: socket.assigns.user.id, goal: goal)
  send_update(DrinkWaterWeb.NextAlarmComponent, id: "next-alarm", user_id: socket.assigns.user.id)
  send_update(DrinkWaterWeb.AlarmSettingsComponent, id: "alarm-settings", user_id: socket.assigns.user.id)
  send_update(DrinkWaterWeb.WeeklySummaryComponent, id: "weekly-summary", user_id: socket.assigns.user.id, goal: goal)

  {:noreply, assign(socket, goal: goal)}
end
```

- [ ] **Step 8: Run tests to verify they pass**

Run: `mix test test/drink_water_web/live/dashboard_live_test.exs`
Expected: PASS

- [ ] **Step 9: Run full test suite**

Run: `mix test`
Expected: ALL PASS (existing REST tests should still pass with broadcasts added)

- [ ] **Step 10: Run mix precommit**

Run: `mix precommit`
Expected: All checks pass

- [ ] **Step 11: Commit**

```bash
git add lib/drink_water/user_management.ex \
        lib/drink_water_web/live/alarm_settings_component.ex \
        lib/drink_water_web/live/dashboard_live.ex \
        lib/drink_water_web/live/dashboard_live.html.heex \
        test/drink_water/pubsub_broadcast_test.exs \
        test/drink_water_web/live/dashboard_live_test.exs
git commit -m "Step 8g: Add AlarmSettingsComponent with edit and :alarm_settings_updated broadcast"
```

---

## Chunk 8: Task 10 — Roadmap Update and Final Verification

### Task 10: Update MIGRATION_ROADMAP.md and final checks

**Files:**

- Modify: `MIGRATION_ROADMAP.md`

- [ ] **Step 1: Run full test suite**

Run: `mix test`
Expected: ALL PASS

- [ ] **Step 2: Run mix precommit**

Run: `mix precommit`
Expected: All checks pass

- [ ] **Step 3: Verify dashboard works in browser**

Run: `mix phx.server`
Open: `http://localhost:4000/dashboard`
Verify: All 6 cards render, progress ring shows, can log water and see real-time updates.

- [ ] **Step 4: Update MIGRATION_ROADMAP.md — mark sub-steps as done as each is completed**

As each sub-step (8a through 8g) is completed and committed, mark it as done:

```markdown
- [x] 8a: Base structure (DashboardLive, route, layout, PubSub subscribe)
```

After all sub-steps are done, mark the entire Step 8:

```markdown
- [x] Step 8: LiveView dashboard with PubSub (real-time hydration tracking)
```

- [ ] **Step 5: Final commit**

```bash
git add MIGRATION_ROADMAP.md
git commit -m "Step 8: Mark LiveView dashboard with PubSub as complete"
```
