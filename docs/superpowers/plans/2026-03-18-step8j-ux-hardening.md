# Step 8j: UX Hardening — Loading States, Accessibility, Timezone, LiveView Rate Limiting

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Harden the LiveView dashboard with loading feedback, accessible font sizes, local timezone display, and server-side rate limiting to protect against abusive users.

**Architecture:** Four independent streams — (1) client-side button protection via `phx-disable-with` and `phx-throttle`, (2) CSS-only font size increase, (3) timezone capture via LiveSocket `connect_params` + server-side `DateTime.shift_zone/2`, (4) server-side LiveView rate limiting reusing the existing Hammer ETS backend. No schema changes. `tzdata` added as dependency for timezone conversion.

**Tech Stack:** Phoenix LiveView (phx-disable-with, phx-throttle, get_connect_params), daisyUI, Hammer v7 ETS, tzdata (Elixir timezone database), JavaScript Intl API

**Spec:** This plan is self-contained (no separate spec document).

---

## File Map

### Modified files

| File | Changes |
|---|---|
| `assets/js/app.js` | Send browser timezone via `params` in LiveSocket constructor |
| `lib/drink_water_web/endpoint.ex` | Add `:peer` to `connect_info` for IP-based rate limiting |
| `lib/drink_water_web/live/dashboard_live.ex` | Capture timezone from `get_connect_params`, assign to socket, pass to children |
| `lib/drink_water_web/live/dashboard_live.html.heex` | Pass `timezone` to HistoryComponent |
| `lib/drink_water_web/live/intake_form_component.ex` | Add `phx-disable-with` on submit, `phx-throttle` on quick-log buttons |
| `lib/drink_water_web/live/alarm_settings_component.ex` | `phx-disable-with` on save, increase font sizes in display view |
| `lib/drink_water_web/live/edit_intake_component.ex` | `phx-disable-with` on save |
| `lib/drink_water_web/live/history_component.ex` | `phx-throttle` on nav/delete buttons, convert times to local timezone |
| `lib/drink_water_web/live/next_alarm_component.ex` | Increase font sizes for label text |
| `lib/drink_water_web/live/progress_component.ex` | Increase stat-desc font size |
| `mix.exs` | Add `tzdata` dependency |
| `config/config.exs` | Configure `tzdata` as Calendar.TimeZoneDatabase |
| `test/drink_water_web/live/dashboard_live_test.exs` | Update tests for timezone + rate limiting |

### New files

| File | Purpose |
|---|---|
| `lib/drink_water_web/live/live_rate_limit.ex` | Reusable module for LiveView event rate limiting using Hammer |
| `test/drink_water_web/live/live_rate_limit_test.exs` | Tests for LiveView rate limiting |

---

## Chunk 1: Task 1 — Button loading states (phx-disable-with + phx-throttle)

### Task 1: Add loading feedback and throttle to all interactive buttons

**Files:**

- Modify: `lib/drink_water_web/live/intake_form_component.ex`
- Modify: `lib/drink_water_web/live/alarm_settings_component.ex`
- Modify: `lib/drink_water_web/live/edit_intake_component.ex`
- Modify: `lib/drink_water_web/live/history_component.ex`

**Rationale:**
- `phx-disable-with` disables the button and changes text during the server round-trip. Prevents double-submit.
- `phx-throttle="N"` ignores repeated events within N ms. Prevents click-spam.
- Navigation buttons (prev/next day) use `phx-throttle` only (no visual change needed).
- Delete buttons use `phx-throttle` to prevent accidental rapid deletes.
- Form submit buttons use `phx-disable-with` for visual feedback.

- [ ] **Step 1: IntakeFormComponent — protect submit and quick-log buttons**

In `lib/drink_water_web/live/intake_form_component.ex`:

Add `phx-disable-with` to the form submit button:
```heex
<button type="submit" class="btn btn-primary" phx-disable-with={gettext("Logging...")}>
  {gettext("Log")}
</button>
```

Add `phx-throttle="1000"` to each quick-log button:
```heex
<button
  :for={volume <- @quick_volumes}
  phx-click="quick-log"
  phx-value-volume={volume}
  phx-target={@myself}
  phx-throttle="1000"
  class="btn btn-primary btn-sm"
>
  {volume}ml
</button>
```

- [ ] **Step 2: AlarmSettingsComponent — protect save button**

In `lib/drink_water_web/live/alarm_settings_component.ex`, update the save button:
```heex
<button type="submit" class="join-item btn btn-primary btn-sm" phx-disable-with={gettext("Saving...")}>
  {gettext("Save")}
</button>
```

- [ ] **Step 3: EditIntakeComponent — protect save button**

In `lib/drink_water_web/live/edit_intake_component.ex`, update the save button:
```heex
<button type="submit" class="join-item btn btn-primary btn-sm" phx-disable-with={gettext("Saving...")}>
  {gettext("Save")}
</button>
```

- [ ] **Step 4: HistoryComponent — throttle nav and action buttons**

In `lib/drink_water_web/live/history_component.ex`:

Add `phx-throttle="500"` to navigation buttons (nav-prev, nav-today, nav-next):
```heex
<button phx-click="nav-prev" phx-target={@myself} phx-throttle="500" ...>
```
```heex
<button phx-click="nav-today" phx-target={@myself} phx-throttle="500" ...>
```
```heex
<button phx-click="nav-next" phx-target={@myself} phx-throttle="500" ...>
```

Add `phx-throttle="1000"` to delete buttons (prevent accidental double-delete):
```heex
<button phx-click="delete" phx-value-id={intake.id} phx-target={@myself} phx-throttle="1000" ...>
```

- [ ] **Step 5: Run mix precommit**

Run: `mix precommit`
Expected: All checks pass

- [ ] **Step 6: Commit**

```bash
git add lib/drink_water_web/live/intake_form_component.ex \
        lib/drink_water_web/live/alarm_settings_component.ex \
        lib/drink_water_web/live/edit_intake_component.ex \
        lib/drink_water_web/live/history_component.ex
git commit -m "Step 8j-1: Add phx-disable-with and phx-throttle to all buttons"
```

---

## Chunk 2: Task 2 — Accessible font sizes

### Task 2: Increase font sizes for readability

**Files:**

- Modify: `lib/drink_water_web/live/alarm_settings_component.ex`
- Modify: `lib/drink_water_web/live/next_alarm_component.ex`
- Modify: `lib/drink_water_web/live/progress_component.ex`
- Modify: `lib/drink_water_web/components/core_components.ex`

**Rationale:**
- `text-sm` (14px) on the AlarmSettings display is too small for users with vision issues.
- `label text-xs` on error messages should be `text-sm` minimum.
- daisyUI `label` class defaults to small, muted text — override with explicit sizes where needed.
- Minimum readable size: `text-sm` (14px) for secondary text, `text-base` (16px) for primary content.

- [ ] **Step 1: AlarmSettingsComponent — increase display view font sizes**

In `lib/drink_water_web/live/alarm_settings_component.ex`, change the display `<dl>`:

From: `<dl class="space-y-1 text-sm">`
To: `<dl class="space-y-2">`

The `<dt>` labels already have `class="label"` — add explicit size:
From: `<dt class="label">`
To: `<dt class="label text-sm">`

The `<dd>` values — increase:
From: `<dd class="font-medium">`
To: `<dd class="font-medium text-base">`

Also change nil state:
From: `<p class="label">`
To: `<p class="text-base-content/60">`

- [ ] **Step 2: NextAlarmComponent — increase helper text sizes**

In `lib/drink_water_web/live/next_alarm_component.ex`:

The `label text-xs opacity-40` lines are too faint and small. Change to:
From: `<p class="label text-xs opacity-40">`
To: `<p class="text-sm text-base-content/60">`

The `<p class="label">` lines (interval, "Done for today", "No alarm"):
From: `<p class="label">`
To: `<p class="text-base-content/60">`

The `<p class="label mt-1">` (Next at time):
From: `<p class="label mt-1">`
To: `<p class="text-sm text-base-content/60 mt-1">`

- [ ] **Step 3: ProgressComponent — increase stat-desc readability**

In `lib/drink_water_web/live/progress_component.ex`, the `stat-desc` is fine by default but ensure it's not `text-xs`:

From: `<div class="stat-desc">`
To: `<div class="stat-desc text-sm">`

- [ ] **Step 4: CoreComponents — increase error message size**

In `lib/drink_water_web/components/core_components.ex`, the error component:

From: `<p class="label text-error text-xs">`
To: `<p class="label text-error text-sm">`

- [ ] **Step 5: Run mix precommit**

Run: `mix precommit`
Expected: All checks pass

- [ ] **Step 6: Commit**

```bash
git add lib/drink_water_web/live/alarm_settings_component.ex \
        lib/drink_water_web/live/next_alarm_component.ex \
        lib/drink_water_web/live/progress_component.ex \
        lib/drink_water_web/components/core_components.ex
git commit -m "Step 8j-2: Increase font sizes for accessibility"
```

---

## Chunk 3: Task 3 — Timezone support (client → server)

### Task 3: Display times in the user's local timezone

**Files:**

- Modify: `mix.exs` (add tzdata)
- Modify: `config/config.exs` (configure TimeZoneDatabase)
- Modify: `assets/js/app.js` (send timezone in connect_params)
- Modify: `lib/drink_water_web/live/dashboard_live.ex` (capture timezone, pass to children)
- Modify: `lib/drink_water_web/live/dashboard_live.html.heex` (pass timezone prop)
- Modify: `lib/drink_water_web/live/history_component.ex` (convert UTC → local)
- Test: `test/drink_water_web/live/dashboard_live_test.exs`

**Rationale:**
- DB stores UTC (correct). Browser knows user's timezone via `Intl.DateTimeFormat`.
- Send timezone once in `connect_params` → DashboardLive captures in `mount` → passes to children.
- Only HistoryComponent shows user-facing times (the `%H:%M` display). AlarmSettings times (start/end) are configuration, not display — keep as-is.
- NextAlarmComponent's calculated times are relative (countdown) — timezone doesn't affect them.
- `tzdata` is the standard Elixir timezone database (used by DateTime.shift_zone/2).

- [ ] **Step 1: Add tzdata dependency**

In `mix.exs`, add to `deps`:
```elixir
{:tzdata, "~> 1.1"}
```

Run: `mix deps.get`

- [ ] **Step 2: Configure tzdata as default TimeZoneDatabase**

In `config/config.exs`, add at the top (after `import Config`):
```elixir
config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase
```

- [ ] **Step 3: Send timezone from browser**

In `assets/js/app.js`, update the LiveSocket params:

From:
```javascript
params: {_csrf_token: csrfToken},
```

To:
```javascript
params: {
  _csrf_token: csrfToken,
  timezone: Intl.DateTimeFormat().resolvedOptions().timeZone
},
```

- [ ] **Step 4: Capture timezone in DashboardLive mount**

In `lib/drink_water_web/live/dashboard_live.ex`, add timezone capture to `mount/3`.

**After** the `if connected?(socket)` block and **before** the `{:ok, assign(...)}` return, add:

```elixir
    timezone =
      case get_connect_params(socket) do
        %{"timezone" => tz} when is_binary(tz) and tz != "" -> tz
        _ -> "Etc/UTC"
      end
```

Then add `timezone: timezone` to the existing `assign` call:

From:
```elixir
    {:ok, assign(socket, page_title: gettext("Hydration Dashboard"), user_id: user_id)}
```

To:
```elixir
    {:ok, assign(socket, page_title: gettext("Hydration Dashboard"), user_id: user_id, timezone: timezone)}
```

**Note:** `get_connect_params/1` returns `nil` on the first (static) mount and the actual params on the connected mount. The `case` pattern handles both: `nil` falls through to `_` → `"Etc/UTC"`, and empty strings are also rejected. The existing `if connected?` block (PubSub subscribe, timer, etc.) should NOT be modified.

- [ ] **Step 5: Pass timezone to HistoryComponent**

In `lib/drink_water_web/live/dashboard_live.html.heex`, add `timezone` to the HistoryComponent:

```heex
<.live_component
  module={DrinkWaterWeb.HistoryComponent}
  id="history"
  user_id={@user.id}
  selected_date={@selected_date}
  timezone={@timezone}
/>
```

Also update the `send_update` calls for HistoryComponent in `dashboard_live.ex` (in `handle_info` for `:select_date` and intake events) to include `timezone`:

```elixir
send_update(DrinkWaterWeb.HistoryComponent,
  id: "history",
  user_id: socket.assigns.user.id,
  selected_date: date,
  timezone: socket.assigns.timezone
)
```

Two locations need this change (both use `socket.assigns.user.id`, not `socket.assigns.user_id`):
1. `handle_info({:select_date, date}, socket)` — the `send_update(HistoryComponent, ...)` call
2. `handle_info(event, socket) when event in [:intake_created, :intake_deleted, :intake_updated]` — inside the `if socket.assigns.selected_date == Date.utc_today()` block

- [ ] **Step 6: Convert times in HistoryComponent**

In `lib/drink_water_web/live/history_component.ex`:

Add timezone to `update/2`:
```elixir
  @impl true
  def update(assigns, socket) do
    selected_date =
      assigns[:selected_date] || socket.assigns[:selected_date] || Date.utc_today()

    timezone = assigns[:timezone] || socket.assigns[:timezone] || "Etc/UTC"

    socket =
      socket
      |> assign(:user_id, assigns.user_id)
      |> assign(:selected_date, selected_date)
      |> assign(:timezone, timezone)
      |> load_intakes()

    {:ok, socket}
  end
```

Add a helper function:
```elixir
  defp format_local_time(utc_datetime, timezone) do
    case DateTime.shift_zone(utc_datetime, timezone) do
      {:ok, local} -> Calendar.strftime(local, "%H:%M")
      {:error, _} -> Calendar.strftime(utc_datetime, "%H:%M")
    end
  end
```

Update the render to use it:
From: `<div class="font-mono">{Calendar.strftime(intake.date_time_utc, "%H:%M")}</div>`
To: `<div class="font-mono">{format_local_time(intake.date_time_utc, @timezone)}</div>`

- [ ] **Step 7: Update tests**

Existing tests use `live(conn, ~p"/dashboard")` which has no connect_params — the `"Etc/UTC"` fallback applies, so existing assertions are unchanged.

Add a new test to `test/drink_water_web/live/dashboard_live_test.exs` to verify the timezone assign exists:

```elixir
    test "assigns timezone as Etc/UTC when no connect_params", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")
      assert render(view) =~ "History"
      # Timezone defaults to UTC — times display unchanged
    end
```

Run: `mix test test/drink_water_web/live/dashboard_live_test.exs`
Expected: All pass (UTC fallback preserves behavior)

- [ ] **Step 8: Run mix precommit**

Run: `mix precommit`
Expected: All checks pass

- [ ] **Step 9: Commit**

```bash
git add mix.exs mix.lock config/config.exs assets/js/app.js \
        lib/drink_water_web/live/dashboard_live.ex \
        lib/drink_water_web/live/dashboard_live.html.heex \
        lib/drink_water_web/live/history_component.ex
git commit -m "Step 8j-3: Display water intake times in user's local timezone"
```

---

## Chunk 4: Task 4 — Server-side LiveView rate limiting

### Task 4: Rate limit LiveView events to protect against malicious users

**Files:**

- Create: `lib/drink_water_web/live/live_rate_limit.ex`
- Modify: `lib/drink_water_web/endpoint.ex` (add `:peer` to connect_info)
- Modify: `lib/drink_water_web/live/dashboard_live.ex` (capture IP, rate limit on mount)
- Modify: `lib/drink_water_web/live/intake_form_component.ex` (rate limit save + quick-log)
- Modify: `lib/drink_water_web/live/history_component.ex` (rate limit delete)
- Modify: `lib/drink_water_web/live/alarm_settings_component.ex` (rate limit save)
- Create: `test/drink_water_web/live/live_rate_limit_test.exs`

**Rationale:**
- `phx-throttle` is client-side only — a malicious user can bypass it with a WebSocket client.
- Reuse existing Hammer ETS backend (`DrinkWater.RateLimit`) — same infra as REST API.
- Rate limit by `user_id` (not IP) since dashboard is user-scoped. IP available as fallback.
- Key structure: `"lv:{user_id}:{action_group}"` — similar to REST rate limit keys.
- Limits: 30 writes/min (create/update/delete), 120 reads/min (nav/view). Generous but prevents abuse.
- On rate limit hit: push a flash warning (not a hard disconnect).

**Design:**
- `LiveRateLimit` module wraps `DrinkWater.RateLimit.hit/3` with a LiveView-friendly API.
- Components call `LiveRateLimit.check/3` in their `handle_event` — returns `:allow` or `{:deny, socket}`.
- On deny: sets a flash message "Too many requests, please slow down" and returns `{:noreply, socket}`.

**IMPORTANT:** This task only modifies `handle_event` callback bodies and adds `alias` lines. Do NOT touch `render/1` functions or templates — those were already modified in Task 1 (phx-throttle/phx-disable-with).

- [ ] **Step 1: Add `:peer` to connect_info**

In `lib/drink_water_web/endpoint.ex`, update the socket config:

From:
```elixir
socket "/live", Phoenix.LiveView.Socket,
  websocket: [connect_info: [session: @session_options]],
  longpoll: [connect_info: [session: @session_options]]
```

To:
```elixir
socket "/live", Phoenix.LiveView.Socket,
  websocket: [connect_info: [:peer, session: @session_options]],
  longpoll: [connect_info: [:peer, session: @session_options]]
```

- [ ] **Step 2: Create LiveRateLimit module**

Create `lib/drink_water_web/live/live_rate_limit.ex`:

```elixir
defmodule DrinkWaterWeb.LiveRateLimit do
  @moduledoc """
  Server-side rate limiting for LiveView events.
  Reuses the Hammer ETS backend from DrinkWater.RateLimit.

  ## Usage in a LiveComponent handle_event:

      case LiveRateLimit.check(socket, "write", 30) do
        {:allow, _count} ->
          # proceed with the action
          {:noreply, socket}

        {:deny, socket} ->
          # socket already has flash set
          {:noreply, socket}
      end

  Key format: "lv:{user_id}:{action_group}"
  Default window: 60 seconds.
  """

  import DrinkWaterWeb.Gettext

  @default_scale :timer.minutes(1)

  @doc """
  Check rate limit for the current user and action group.

  Returns `{:allow, count}` or `{:deny, socket}` with a flash message.
  """
  def check(socket, action_group, limit, opts \\ []) do
    scale = Keyword.get(opts, :scale, @default_scale)
    user_id = socket.assigns[:user_id] || "anonymous"
    key = "lv:#{user_id}:#{action_group}"

    if enabled?() do
      case DrinkWater.RateLimit.hit(key, scale, limit) do
        {:allow, count} ->
          {:allow, count}

        {:deny, _retry_after_ms} ->
          socket =
            Phoenix.LiveView.put_flash(
              socket,
              :error,
              gettext("Too many requests. Please slow down.")
            )

          {:deny, socket}
      end
    else
      {:allow, 0}
    end
  end

  defp enabled?, do: Application.get_env(:drink_water, :rate_limiting_enabled, true)
end
```

- [ ] **Step 3: Rate limit IntakeFormComponent**

In `lib/drink_water_web/live/intake_form_component.ex`:

Add alias at top: `alias DrinkWaterWeb.LiveRateLimit`

Wrap `handle_event("save", ...)`:
```elixir
  @impl true
  def handle_event("save", %{"intake" => params}, socket) do
    case LiveRateLimit.check(socket, "write", 30) do
      {:allow, _} ->
        do_save(socket, params)

      {:deny, socket} ->
        {:noreply, socket}
    end
  end

  defp do_save(socket, params) do
    attrs =
      params
      |> Map.put("date_time_utc", DateTime.utc_now())
      |> Map.put("volume_unit", "ml")

    case HydrationTracking.create_water_intake(socket.assigns.user_id, attrs) do
      {:ok, _intake} ->
        send(self(), {:flash, :info, gettext("Water logged!")})
        changeset = WaterIntake.changeset(%WaterIntake{}, %{})
        {:noreply, assign(socket, form: to_form(changeset, as: :intake))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: :intake))}
    end
  end
```

Wrap `handle_event("quick-log", ...)` similarly:
```elixir
  @impl true
  def handle_event("quick-log", %{"volume" => volume_str}, socket) do
    case LiveRateLimit.check(socket, "write", 30) do
      {:allow, _} ->
        do_quick_log(socket, volume_str)

      {:deny, socket} ->
        {:noreply, socket}
    end
  end

  defp do_quick_log(socket, volume_str) do
    # ... existing quick-log logic moved here ...
  end
```

- [ ] **Step 4: Rate limit HistoryComponent delete**

In `lib/drink_water_web/live/history_component.ex`:

Add alias: `alias DrinkWaterWeb.LiveRateLimit`

Wrap `handle_event("delete", ...)`:
```elixir
  @impl true
  def handle_event("delete", %{"id" => id_str}, socket) do
    case LiveRateLimit.check(socket, "write", 30) do
      {:allow, _} ->
        do_delete(socket, id_str)

      {:deny, socket} ->
        {:noreply, socket}
    end
  end

  defp do_delete(socket, id_str) do
    # ... existing delete logic moved here ...
  end
```

- [ ] **Step 5: Rate limit AlarmSettingsComponent save**

In `lib/drink_water_web/live/alarm_settings_component.ex`:

Add alias: `alias DrinkWaterWeb.LiveRateLimit`

Wrap `handle_event("save", ...)`:
```elixir
  @impl true
  def handle_event("save", %{"alarm_settings" => params}, socket) do
    case LiveRateLimit.check(socket, "write", 30) do
      {:allow, _} ->
        do_save(socket, params)

      {:deny, socket} ->
        {:noreply, socket}
    end
  end

  defp do_save(socket, params) do
    case UserManagement.update_alarm_settings(socket.assigns.alarm_settings, params) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> assign(alarm_settings: updated, editing: false)
         |> assign_form(updated)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: :alarm_settings))}
    end
  end
```

- [ ] **Step 6: Write tests for LiveRateLimit**

Create `test/drink_water_web/live/live_rate_limit_test.exs`:

```elixir
defmodule DrinkWaterWeb.LiveRateLimitTest do
  use DrinkWater.DataCase, async: false

  alias DrinkWaterWeb.LiveRateLimit

  # Build a minimal socket-like struct for testing
  defp socket_with_user(user_id) do
    %Phoenix.LiveView.Socket{
      assigns: %{__changed__: %{}, user_id: user_id, flash: %{}}
    }
  end

  describe "check/3" do
    test "allows requests within limit" do
      socket = socket_with_user(99_001)
      assert {:allow, _} = LiveRateLimit.check(socket, "test", 5)
    end

    test "denies requests over limit" do
      socket = socket_with_user(99_002)

      for _ <- 1..5 do
        assert {:allow, _} = LiveRateLimit.check(socket, "test-deny", 5)
      end

      assert {:deny, denied_socket} = LiveRateLimit.check(socket, "test-deny", 5)
      assert denied_socket.assigns.flash["error"] =~ "Too many requests"
    end

    test "different action groups have independent limits" do
      socket = socket_with_user(99_003)

      for _ <- 1..3 do
        assert {:allow, _} = LiveRateLimit.check(socket, "group-a", 3)
      end

      # group-a exhausted
      assert {:deny, _} = LiveRateLimit.check(socket, "group-a", 3)
      # group-b still has budget
      assert {:allow, _} = LiveRateLimit.check(socket, "group-b", 3)
    end
  end
end
```

- [ ] **Step 7: Run mix precommit**

Run: `mix precommit`
Expected: All checks pass

- [ ] **Step 8: Commit**

```bash
git add lib/drink_water_web/endpoint.ex \
        lib/drink_water_web/live/live_rate_limit.ex \
        lib/drink_water_web/live/intake_form_component.ex \
        lib/drink_water_web/live/history_component.ex \
        lib/drink_water_web/live/alarm_settings_component.ex \
        test/drink_water_web/live/live_rate_limit_test.exs
git commit -m "Step 8j-4: Add server-side rate limiting for LiveView events"
```
