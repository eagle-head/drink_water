# Idiomatic Elixir: if/else → Pattern Matching Refactor

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace imperative if/else constructs with idiomatic Elixir patterns (multi-clause functions, case, with, guards) across the entire codebase — pure refactor, zero behavior change.

**Architecture:** Each task targets one file. Every refactor is behavior-preserving: existing tests must continue to pass unchanged. No new tests are needed unless existing coverage is insufficient for the refactored code path. Tasks are independent and can be executed in any order.

**Tech Stack:** Elixir pattern matching, multi-clause functions, case expressions, with chains, guards

**Spec:** This plan is self-contained (no separate spec document).

---

## File Map

### Modified files

| File | Changes |
|---|---|
| `lib/drink_water_web/controllers/health_controller.ex` | Two inline `if` → single `case` with tuple destructuring |
| `lib/drink_water/hydration_tracking.ex` | `if dir == "desc"` → multi-clause function; `if length > size` → `Enum.split`; `if cursor_value` → `case` |
| `lib/drink_water/hydration_tracking.ex` | (also) `if has_unique_constraint_error?` → `case` pattern match |
| `lib/drink_water/user_management.ex` | `if has_unique_constraint_error?` → `case` pattern match |
| `lib/drink_water/user_management/alarm_settings.ex` | `if start_time && end_time && ...` → multi-clause with guards |
| `lib/drink_water/hydration_tracking/water_intake.ex` | `if DateTime.after?` → `case DateTime.compare` |
| `lib/drink_water/hydration_tracking/water_intake_filter.ex` | Two `if x && y && ...` → multi-clause with guards |
| `lib/drink_water_web/plugs/rate_limiter.ex` | DROPPED — `if enabled?()` is already idiomatic for boolean branch |
| `lib/drink_water_web/live/live_rate_limit.ex` | `if enabled?()` → early return with `case`, skips unnecessary computation |
| `lib/drink_water_web/live/edit_intake_component.ex` | `if socket.assigns[:form]` → `case` on assigns map pattern |
| `lib/drink_water_web/live/next_alarm_component.ex` | Two chained inline `if` → `with`; inline `if Time.compare` → `case` |
| `lib/drink_water_web/live/history_component.ex` | `if Date.compare != :gt` → `case Date.compare` |
| `lib/drink_water_web/live/dashboard_live.ex` | `if selected_date == today` → extracted helper with `if` (kept — boolean check is idiomatic) |
| `lib/drink_water_web/plugs/log_metadata.ex` | Inline `if user_id` → `case` |

### Files NOT changed (already idiomatic)

| File | Reason |
|---|---|
| `lib/drink_water/user_management/user.ex` | `if {month,day} <` — boolean comparison, `if` is correct; tuple guards won't compile |
| `lib/drink_water_web/live/dashboard_live.ex:19` | `if connected?(socket)` — canonical Phoenix pattern |
| `config/runtime.exs` | Framework-generated config, standard Phoenix patterns |
| `lib/drink_water_web/components/core_components.ex` | Phoenix-generated, inline `if` in templates is standard |
| `lib/drink_water_web/router.ex` | Compile-time `if` for dev routes — standard Phoenix |
| HEEx templates (`.heex`) | `<%= if ... %>` in templates is the standard Phoenix approach |

---

## Task 1: HealthController — Two inline `if` → single `case`

**Files:**
- Modify: `lib/drink_water_web/controllers/health_controller.ex:6-7`
- Test: `test/drink_water_web/controllers/health_controller_test.exs` (existing, no changes)

**Rationale:** Two separate `if` expressions derive `status_code` and `overall` from the same `db_status` value. A single `case` with tuple destructuring is cleaner and avoids evaluating the condition twice.

- [ ] **Step 1: Refactor the two `if` into a single `case`**

In `lib/drink_water_web/controllers/health_controller.ex`, replace lines 5-7:

```elixir
# Before:
db_status = check_db()
status_code = if db_status == :ok, do: 200, else: 503
overall = if db_status == :ok, do: :healthy, else: :degraded

# After:
{status_code, overall} =
  case check_db() do
    :ok -> {200, :healthy}
    :error -> {503, :degraded}
  end
```

Note: `db_status` is no longer needed as a separate variable since `check_db()` is consumed directly by the `case`. The `db_status` key in the JSON response (`database: db_status`) must also be updated — use `database: if(status_code == 200, do: :ok, else: :error)` or extract the status. Simpler: keep `db_status` and use it in the case:

```elixir
db_status = check_db()

{status_code, overall} =
  case db_status do
    :ok -> {200, :healthy}
    :error -> {503, :degraded}
  end
```

This preserves `db_status` for the JSON response body.

- [ ] **Step 2: Run tests to verify no behavior change**

Run: `mix test test/drink_water_web/controllers/health_controller_test.exs --trace`
Expected: All tests PASS

- [ ] **Step 3: Commit**

```bash
git add lib/drink_water_web/controllers/health_controller.ex
git commit -m "refactor: health_controller if/else → case with tuple destructuring"
```

---

## Task 2: HydrationTracking — `apply_cursor` direction branching → multi-clause

**Files:**
- Modify: `lib/drink_water/hydration_tracking.ex:260-290` (apply_cursor) and `292-301` (build_page) and `313-327` (decode_cursor)
- Test: `test/drink_water/hydration_tracking_test.exs` (existing, no changes)

**Rationale:** Three if/else blocks in this module can be replaced with more idiomatic patterns.

- [ ] **Step 1: Extract `apply_direction/5` as multi-clause function**

Replace the `if dir == "desc"` block (lines 265-280) with two function clauses:

```elixir
# Before (inside apply_cursor):
filtered =
  if dir == "desc" do
    where(query, [w], field(w, ^sort_field) < ^cursor_value or ...)
  else
    where(query, [w], field(w, ^sort_field) > ^cursor_value or ...)
  end

# After — extract to private function:
defp apply_direction(query, sort_field, cursor_value, cursor_id, "desc") do
  where(
    query,
    [w],
    field(w, ^sort_field) < ^cursor_value or
      (field(w, ^sort_field) == ^cursor_value and w.id < ^cursor_id)
  )
end

defp apply_direction(query, sort_field, cursor_value, cursor_id, "asc") do
  where(
    query,
    [w],
    field(w, ^sort_field) > ^cursor_value or
      (field(w, ^sort_field) == ^cursor_value and w.id > ^cursor_id)
  )
end
```

And in `apply_cursor`, the match arm becomes:

```elixir
{:ok, cursor_value, cursor_id, cursor_field} when cursor_field == field ->
  {:ok, apply_direction(query, sort_field, cursor_value, cursor_id, dir)}
```

- [ ] **Step 2: Run tests to verify**

Run: `mix test test/drink_water/hydration_tracking_test.exs --trace`
Expected: All tests PASS

- [ ] **Step 3: Refactor `build_page` — `if length > size` → `Enum.split`**

```elixir
# Before:
defp build_page(entries, %{size: size, sort_field: field} = _filter) do
  if length(entries) > size do
    page = Enum.take(entries, size)
    last = List.last(page)
    sort_value = Map.get(last, Map.fetch!(@sort_field_atoms, field))
    {page, encode_cursor(sort_value, last.id, field)}
  else
    {entries, nil}
  end
end

# After:
defp build_page(entries, %{size: size, sort_field: field}) do
  case Enum.split(entries, size) do
    {page, [_ | _]} ->
      last = List.last(page)
      sort_value = Map.get(last, Map.fetch!(@sort_field_atoms, field))
      {page, encode_cursor(sort_value, last.id, field)}

    {page, []} ->
      {page, nil}
  end
end
```

- [ ] **Step 4: Run tests to verify**

Run: `mix test test/drink_water/hydration_tracking_test.exs --trace`
Expected: All tests PASS

- [ ] **Step 5: Refactor `decode_cursor` — `if cursor_value` → `case`**

```elixir
# Before (inside the with block):
cursor_value = parse_cursor_value(value_str)

if cursor_value do
  {:ok, cursor_value, id, cursor_field}
else
  :error
end

# After:
case parse_cursor_value(value_str) do
  nil -> :error
  cursor_value -> {:ok, cursor_value, id, cursor_field}
end
```

- [ ] **Step 6: Run tests to verify**

Run: `mix test test/drink_water/hydration_tracking_test.exs --trace`
Expected: All tests PASS

- [ ] **Step 7: Commit**

```bash
git add lib/drink_water/hydration_tracking.ex
git commit -m "refactor: hydration_tracking if/else → multi-clause, Enum.split, case"
```

---

## Task 3: UserManagement + HydrationTracking — `maybe_conflict` → `Enum.find` + pattern match

**Files:**
- Modify: `lib/drink_water/user_management.ex:217-232`
- Modify: `lib/drink_water/hydration_tracking.ex:207-221`
- Test: `test/drink_water/user_management_test.exs` (existing, no changes)
- Test: `test/drink_water/hydration_tracking_test.exs` (existing, no changes)

**Rationale:** Both contexts have the same pattern: `if has_unique_constraint_error?(...) do ... end`. Using `Enum.find` with pattern matching on the result is more idiomatic than a boolean check + if branch.

- [ ] **Step 1: Refactor `maybe_conflict` in `user_management.ex` — use `Enum.find` + `case`**

```elixir
# Before:
defp maybe_conflict({:error, %Ecto.Changeset{} = changeset}, resource, field) do
  if has_unique_constraint_error?(changeset, field) do
    {:error, :conflict, resource}
  else
    {:error, changeset}
  end
end

defp maybe_conflict(result, _resource, _field), do: result

defp has_unique_constraint_error?(changeset, field) do
  Enum.any?(changeset.errors, fn
    {^field, {_msg, opts}} -> opts[:constraint] == :unique
    _ -> false
  end)
end

# After:
defp maybe_conflict({:error, %Ecto.Changeset{} = changeset}, resource, field) do
  case Enum.find(changeset.errors, fn
         {^field, {_msg, opts}} -> opts[:constraint] == :unique
         _ -> false
       end) do
    nil -> {:error, changeset}
    _unique_error -> {:error, :conflict, resource}
  end
end

defp maybe_conflict(result, _resource, _field), do: result
```

This eliminates the `has_unique_constraint_error?/2` helper. The `case` matches on the actual data (`nil` vs found error) rather than a boolean.

- [ ] **Step 2: Run tests to verify**

Run: `mix test test/drink_water/user_management_test.exs --trace`
Expected: All tests PASS

- [ ] **Step 3: Refactor `maybe_conflict` in `hydration_tracking.ex` — same pattern (2-arity version)**

```elixir
# Before:
defp maybe_conflict({:error, %Ecto.Changeset{} = changeset}, resource) do
  if has_unique_constraint_error?(changeset) do
    {:error, :conflict, resource}
  else
    {:error, changeset}
  end
end

defp maybe_conflict(result, _resource), do: result

defp has_unique_constraint_error?(changeset) do
  Enum.any?(changeset.errors, fn
    {_field, {_msg, opts}} -> opts[:constraint] == :unique
  end)
end

# After:
defp maybe_conflict({:error, %Ecto.Changeset{} = changeset}, resource) do
  case Enum.find(changeset.errors, fn
         {_field, {_msg, opts}} -> opts[:constraint] == :unique
         _ -> false
       end) do
    nil -> {:error, changeset}
    _unique_error -> {:error, :conflict, resource}
  end
end

defp maybe_conflict(result, _resource), do: result
```

**IMPORTANT:** The original `has_unique_constraint_error?/1` in hydration_tracking uses `Enum.any?` with only one clause (no `_ -> false` fallback). This works because `Enum.any?` doesn't require exhaustive matching — but `Enum.find` does. The refactored version adds `_ -> false` to handle non-unique errors safely.

This also eliminates the `has_unique_constraint_error?/1` helper.

- [ ] **Step 4: Run tests to verify**

Run: `mix test test/drink_water/hydration_tracking_test.exs --trace`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add lib/drink_water/user_management.ex lib/drink_water/hydration_tracking.ex
git commit -m "refactor: maybe_conflict if/else → Enum.find + case pattern match"
```

---

## Task 4: DROPPED — `age_from_birth_date` is already idiomatic

**Rationale:** The `if {today.month, today.day} < {birth_date.month, birth_date.day}` in `user.ex:77` is a clean boolean expression. Replacing it with `case ... do true -> ... false -> ... end` is a lateral move that adds verbosity. Tuple comparison in guards is not allowed in Elixir (guard restrictions), so multi-clause functions are not an option here either. **The `if` is the correct construct for this boolean branch — no change needed.**

---

## Task 5: AlarmSettings — nil-guard `if` → multi-clause function

**Files:**
- Modify: `lib/drink_water/user_management/alarm_settings.ex:57-66`
- Test: `test/drink_water/user_management_test.exs` (existing, no changes)

- [ ] **Step 1: Split `validate_start_before_end` into two clauses**

```elixir
# Before:
defp validate_start_before_end(changeset) do
  start_time = get_field(changeset, :daily_start_time)
  end_time = get_field(changeset, :daily_end_time)

  if start_time && end_time && Time.compare(start_time, end_time) != :lt do
    add_error(changeset, :daily_end_time, "must be after start time")
  else
    changeset
  end
end

# After:
defp validate_start_before_end(changeset) do
  start_time = get_field(changeset, :daily_start_time)
  end_time = get_field(changeset, :daily_end_time)
  do_validate_start_before_end(changeset, start_time, end_time)
end

defp do_validate_start_before_end(changeset, start_time, end_time)
     when not is_nil(start_time) and not is_nil(end_time) do
  case Time.compare(start_time, end_time) do
    :lt -> changeset
    _not_lt -> add_error(changeset, :daily_end_time, "must be after start time")
  end
end

defp do_validate_start_before_end(changeset, _start_time, _end_time), do: changeset
```

- [ ] **Step 2: Run tests to verify**

Run: `mix test test/drink_water/user_management_test.exs --trace`
Expected: All tests PASS

- [ ] **Step 3: Commit**

```bash
git add lib/drink_water/user_management/alarm_settings.ex
git commit -m "refactor: alarm_settings validate_start_before_end if → multi-clause with guards"
```

---

## Task 6: WaterIntake — `if DateTime.after?` → `case DateTime.compare`

**Files:**
- Modify: `lib/drink_water/hydration_tracking/water_intake.ex:26-34`
- Test: `test/drink_water/hydration_tracking_test.exs` (existing, no changes)

- [ ] **Step 1: Replace `if DateTime.after?` with `case DateTime.compare`**

```elixir
# Before:
defp validate_not_future(changeset) do
  validate_change(changeset, :date_time_utc, fn :date_time_utc, date_time_utc ->
    if DateTime.after?(date_time_utc, DateTime.utc_now()) do
      [date_time_utc: "must not be in the future"]
    else
      []
    end
  end)
end

# After:
defp validate_not_future(changeset) do
  validate_change(changeset, :date_time_utc, fn :date_time_utc, date_time_utc ->
    case DateTime.compare(date_time_utc, DateTime.utc_now()) do
      :gt -> [date_time_utc: "must not be in the future"]
      _not_future -> []
    end
  end)
end
```

- [ ] **Step 2: Run tests to verify**

Run: `mix test test/drink_water/hydration_tracking_test.exs --trace`
Expected: All tests PASS

- [ ] **Step 3: Commit**

```bash
git add lib/drink_water/hydration_tracking/water_intake.ex
git commit -m "refactor: water_intake validate_not_future if → case DateTime.compare"
```

---

## Task 7: WaterIntakeFilter — two nil-guard `if` → multi-clause functions

**Files:**
- Modify: `lib/drink_water/hydration_tracking/water_intake_filter.ex:46-66`
- Test: `test/drink_water/hydration_tracking_test.exs` (existing, no changes)

- [ ] **Step 1: Refactor `validate_date_range`**

```elixir
# Before:
defp validate_date_range(changeset) do
  start_date = get_field(changeset, :start_date)
  end_date = get_field(changeset, :end_date)

  if start_date && end_date && DateTime.after?(start_date, end_date) do
    add_error(changeset, :end_date, "must be after or equal to start_date")
  else
    changeset
  end
end

# After:
defp validate_date_range(changeset) do
  start_date = get_field(changeset, :start_date)
  end_date = get_field(changeset, :end_date)
  do_validate_date_range(changeset, start_date, end_date)
end

defp do_validate_date_range(changeset, start_date, end_date)
     when not is_nil(start_date) and not is_nil(end_date) do
  case DateTime.compare(start_date, end_date) do
    :gt -> add_error(changeset, :end_date, "must be after or equal to start_date")
    _ok -> changeset
  end
end

defp do_validate_date_range(changeset, _start_date, _end_date), do: changeset
```

- [ ] **Step 2: Refactor `validate_volume_range`**

```elixir
# Before:
defp validate_volume_range(changeset) do
  min_vol = get_field(changeset, :min_volume)
  max_vol = get_field(changeset, :max_volume)

  if min_vol && max_vol && min_vol > max_vol do
    add_error(changeset, :max_volume, "must be greater than or equal to min_volume")
  else
    changeset
  end
end

# After:
defp validate_volume_range(changeset) do
  min_vol = get_field(changeset, :min_volume)
  max_vol = get_field(changeset, :max_volume)
  do_validate_volume_range(changeset, min_vol, max_vol)
end

defp do_validate_volume_range(changeset, min_vol, max_vol)
     when not is_nil(min_vol) and not is_nil(max_vol) and min_vol > max_vol do
  add_error(changeset, :max_volume, "must be greater than or equal to min_volume")
end

defp do_validate_volume_range(changeset, _min_vol, _max_vol), do: changeset
```

- [ ] **Step 3: Run tests to verify**

Run: `mix test test/drink_water/hydration_tracking_test.exs --trace`
Expected: All tests PASS

- [ ] **Step 4: Commit**

```bash
git add lib/drink_water/hydration_tracking/water_intake_filter.ex
git commit -m "refactor: water_intake_filter nil-guard if → multi-clause with guards"
```

---

## Task 8: DROPPED — RateLimiter Plug `if enabled?()` is already idiomatic

**Rationale:** `if enabled?() do ... else ... end` is a boolean branch — `if/else` is the canonical Elixir construct for booleans. Replacing with `case true/false` would be a lateral move with no readability gain.

---

## Task 9: LiveRateLimit — `if enabled?()` → restructure with `case`

**Files:**
- Modify: `lib/drink_water_web/live/live_rate_limit.ex:36-53`
- Test: `test/drink_water_web/live/live_rate_limit_test.exs` (existing, no changes)

- [ ] **Step 1: Restructure `check/4` to use `case` for enabled check**

```elixir
# Before:
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

# After:
def check(socket, action_group, limit, opts \\ []) do
  case enabled?() do
    false ->
      {:allow, 0}

    true ->
      scale = Keyword.get(opts, :scale, @default_scale)
      user_id = socket.assigns[:user_id] || "anonymous"
      key = "lv:#{user_id}:#{action_group}"

      case DrinkWater.RateLimit.hit(key, scale, limit) do
        {:allow, count} ->
          {:allow, count}

        {:deny, _retry_after_ms} ->
          {:deny,
           Phoenix.LiveView.put_flash(
             socket,
             :error,
             gettext("Too many requests. Please slow down.")
           )}
      end
  end
end
```

**Note:** This also avoids computing `scale`, `user_id`, and `key` when rate limiting is disabled — a minor optimization beyond pure refactor, but harmless and makes the flow clearer.

- [ ] **Step 2: Run tests to verify**

Run: `mix test test/drink_water_web/live/live_rate_limit_test.exs --trace`
Expected: All tests PASS

- [ ] **Step 3: Commit**

```bash
git add lib/drink_water_web/live/live_rate_limit.ex
git commit -m "refactor: live_rate_limit if enabled? → case, skip computation when disabled"
```

---

## Task 10: EditIntakeComponent — `if socket.assigns[:form]` → pattern match

**Files:**
- Modify: `lib/drink_water_web/live/edit_intake_component.ex:8-19`
- Test: `test/drink_water_web/live/dashboard_live_test.exs` (existing, no changes — edit modal is tested via DashboardLive)

- [ ] **Step 1: Replace `if socket.assigns[:form]` with `case` map pattern matching**

```elixir
# Before:
def update(assigns, socket) do
  socket = assign(socket, :intake, assigns.intake)

  socket =
    if socket.assigns[:form] do
      socket
    else
      changeset = WaterIntake.changeset(assigns.intake, %{})
      assign(socket, :form, to_form(changeset, as: :intake))
    end

  {:ok, socket}
end

# After:
def update(assigns, socket) do
  socket = assign(socket, :intake, assigns.intake)

  socket =
    case socket.assigns do
      %{form: _} ->
        socket

      _ ->
        changeset = WaterIntake.changeset(assigns.intake, %{})
        assign(socket, :form, to_form(changeset, as: :intake))
    end

  {:ok, socket}
end
```

This uses true Elixir pattern matching on the map structure instead of a boolean check. The `%{form: _}` pattern matches when the key exists regardless of value — more expressive than `Map.has_key?` or `socket.assigns[:form]`.

- [ ] **Step 2: Run tests to verify**

Run: `mix test test/drink_water_web/live/dashboard_live_test.exs --trace`
Expected: All tests PASS

- [ ] **Step 3: Commit**

```bash
git add lib/drink_water_web/live/edit_intake_component.ex
git commit -m "refactor: edit_intake_component if assigns[:form] → case map pattern match"
```

---

## Task 11: NextAlarmComponent — chained inline `if` → `with`, inline `if` → `case`

**Files:**
- Modify: `lib/drink_water_web/live/next_alarm_component.ex:7-18` and `46`
- Test: `test/drink_water_web/live/dashboard_live_test.exs` (existing, no changes)

- [ ] **Step 1: Replace chained `if` in `update/2` with a `with`-like pipeline**

```elixir
# Before:
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

# After:
def update(assigns, socket) do
  alarm_settings = load_alarm_settings(assigns.user_id)
  now = Map.get(assigns, :now, Time.utc_now())

  {next_alarm, countdown} =
    with settings when not is_nil(settings) <- alarm_settings,
         next when not is_nil(next) <- calculate_next_alarm(settings, now) do
      {next, calculate_countdown(next, now)}
    else
      _ -> {nil, nil}
    end

  {:ok,
   socket
   |> assign(:user_id, assigns.user_id)
   |> assign(:alarm_settings, alarm_settings)
   |> assign(:next_alarm, next_alarm)
   |> assign(:countdown, countdown)}
end
```

- [ ] **Step 2: Replace inline `if Time.compare` with `case` in `calculate_next_alarm`**

```elixir
# Before (line 46):
if Time.compare(next_time, end_time) != :gt, do: next_time, else: nil

# After:
case Time.compare(next_time, end_time) do
  :gt -> nil
  _ok -> next_time
end
```

- [ ] **Step 3: Run tests to verify**

Run: `mix test test/drink_water_web/live/dashboard_live_test.exs --trace`
Expected: All tests PASS

- [ ] **Step 4: Commit**

```bash
git add lib/drink_water_web/live/next_alarm_component.ex
git commit -m "refactor: next_alarm_component chained if → with, inline if → case"
```

---

## Task 12: HistoryComponent — `if Date.compare != :gt` → `case`

**Files:**
- Modify: `lib/drink_water_web/live/history_component.ex:42-49`
- Test: `test/drink_water_web/live/dashboard_live_test.exs` (existing, no changes)

- [ ] **Step 1: Replace `if Date.compare` with `case`**

```elixir
# Before:
def handle_event("nav-next", _params, socket) do
  new_date = Date.add(socket.assigns.selected_date, 1)

  if Date.compare(new_date, Date.utc_today()) != :gt do
    send(self(), {:select_date, new_date})
  end

  {:noreply, socket}
end

# After:
def handle_event("nav-next", _params, socket) do
  new_date = Date.add(socket.assigns.selected_date, 1)

  case Date.compare(new_date, Date.utc_today()) do
    :gt -> :noop
    _ok -> send(self(), {:select_date, new_date})
  end

  {:noreply, socket}
end
```

- [ ] **Step 2: Run tests to verify**

Run: `mix test test/drink_water_web/live/dashboard_live_test.exs --trace`
Expected: All tests PASS

- [ ] **Step 3: Commit**

```bash
git add lib/drink_water_web/live/history_component.ex
git commit -m "refactor: history_component if Date.compare → case"
```

---

## Task 13: DashboardLive — extract `maybe_update_daily_components` helper

**Files:**
- Modify: `lib/drink_water_web/live/dashboard_live.ex:83-112`
- Test: `test/drink_water_web/live/dashboard_live_test.exs` (existing, no changes)

**Rationale:** The `if selected_date == today` is a valid boolean check — `if` is the right construct here. But extracting it into a named helper improves readability of the `handle_info` callback. The `if` itself stays as-is.

- [ ] **Step 1: Extract conditional update logic into helper (keeping `if`)**

```elixir
# After — extract to private function:
defp maybe_update_daily_components(socket) do
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
      selected_date: socket.assigns.selected_date,
      timezone: socket.assigns.timezone
    )
  end
end
```

And the `handle_info` becomes:

```elixir
def handle_info(event, socket)
    when event in [:intake_created, :intake_deleted, :intake_updated] do
  send_update(DrinkWaterWeb.WeeklySummaryComponent,
    id: "weekly-summary",
    user_id: socket.assigns.user.id,
    goal: socket.assigns.goal,
    selected_date: socket.assigns.selected_date
  )

  maybe_update_daily_components(socket)

  {:noreply, socket}
end
```

- [ ] **Step 2: Run tests to verify**

Run: `mix test test/drink_water_web/live/dashboard_live_test.exs --trace`
Expected: All tests PASS

- [ ] **Step 3: Commit**

```bash
git add lib/drink_water_web/live/dashboard_live.ex
git commit -m "refactor: dashboard_live extract maybe_update_daily_components helper"
```

---

## Task 14: LogMetadata — inline `if user_id` → `case`

**Files:**
- Modify: `lib/drink_water_web/plugs/log_metadata.ex:11-14`
- Test: No dedicated test file exists. This is a simple plug tested indirectly via integration.

- [ ] **Step 1: Replace inline `if` with `case`**

```elixir
# Before:
def call(conn, _opts) do
  user_id = conn.params["user_id"] || conn.params["id"]
  if user_id, do: Logger.metadata(user_id: user_id)
  conn
end

# After:
def call(conn, _opts) do
  case conn.params["user_id"] || conn.params["id"] do
    nil -> :ok
    user_id -> Logger.metadata(user_id: user_id)
  end

  conn
end
```

- [ ] **Step 2: Run full test suite to verify**

Run: `mix test --trace`
Expected: All tests PASS

- [ ] **Step 3: Commit**

```bash
git add lib/drink_water_web/plugs/log_metadata.ex
git commit -m "refactor: log_metadata inline if → case"
```

---

## Task 15: Final verification

- [ ] **Step 1: Run `mix precommit`**

Run: `mix precommit`
Expected: Compilation with zero warnings, formatting clean, all tests PASS.

- [ ] **Step 2: Verify no remaining imperative if/else in business logic**

Search for remaining `if` in `lib/` (excluding templates, config, and framework code):

```bash
grep -rn '\bif\b' lib/drink_water/ lib/drink_water_web/controllers/ lib/drink_water_web/plugs/ lib/drink_water_web/live/ --include='*.ex' | grep -v '\.heex' | grep -v '#'
```

Review any remaining occurrences — they should only be `if connected?(socket)` in `dashboard_live.ex` (canonical Phoenix pattern).
