# Pre-Step 8 Gap Closure Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close 4 behavioral gaps between the Java source and Phoenix target before starting Phase 4 (LiveView).

**Architecture:** Each gap is self-contained — touches different layers (schema validation, query composition, router pipelines, controller logic). No cross-dependencies between tasks, so they can be implemented in any order. All changes follow existing project patterns: Ecto changesets for validation, composable query functions, Plug pipelines for rate limiting, and `{:ok, _} | {:error, _, _}` tuples for control flow.

**Tech Stack:** Elixir 1.15+, Phoenix 1.8, Ecto 3.13, Hammer 7, ExUnit

---

## File Structure

| Task | Files to Create/Modify |
|------|----------------------|
| 1. Name validation | Modify: `lib/drink_water/user_management/user.ex`, `test/drink_water/user_management_test.exs`, `test/drink_water_web/controllers/user_controller_test.exs` |
| 2. Search rate limit | Modify: `lib/drink_water_web/router.ex`, `test/drink_water_web/plugs/rate_limiter_test.exs` |
| 3. Sort field/direction | Modify: `lib/drink_water/hydration_tracking/water_intake_filter.ex`, `lib/drink_water/hydration_tracking.ex`, `test/drink_water/hydration_tracking_test.exs`, `test/drink_water_web/controllers/water_intake_controller_test.exs`, `lib/drink_water_web/controllers/water_intake_controller.ex` |
| 4. Idempotent user delete | Modify: `lib/drink_water/user_management.ex`, `lib/drink_water_web/controllers/user_controller.ex`, `test/drink_water/user_management_test.exs`, `test/drink_water_web/controllers/user_controller_test.exs` |

---

## Task 1: Name Format Validation (first_name, last_name)

**Context:** Currently only length (2-50) is validated. Java enforces a character class: letters (including accented Latin), apostrophes, hyphens, and spaces. Phoenix should replicate the *behavior* (reject numbers, special chars, control chars) using `validate_format/4`.

**Files:**
- Modify: `lib/drink_water/user_management/user.ex:37-48` (changeset)
- Test: `test/drink_water/user_management_test.exs`
- Test: `test/drink_water_web/controllers/user_controller_test.exs`

### Step 1.1: Write failing context tests for name validation

- [ ] **Add test: rejects names with numbers**

```elixir
# In test/drink_water/user_management_test.exs, inside describe "users"
test "create_user/1 rejects first_name with numbers" do
  attrs = %{
    email: "num@example.com",
    first_name: "John123",
    last_name: "Doe",
    birth_date: ~D[1990-01-01],
    biological_sex: :male,
    weight: "75.0",
    weight_unit: :kg,
    height: "175.0",
    height_unit: :cm
  }

  assert {:error, changeset} = UserManagement.create_user(attrs)
  assert changeset.errors[:first_name]
end
```

- [ ] **Add test: rejects names with special characters**

```elixir
test "create_user/1 rejects last_name with special characters" do
  attrs = %{
    email: "spec@example.com",
    first_name: "John",
    last_name: "Doe<script>",
    birth_date: ~D[1990-01-01],
    biological_sex: :male,
    weight: "75.0",
    weight_unit: :kg,
    height: "175.0",
    height_unit: :cm
  }

  assert {:error, changeset} = UserManagement.create_user(attrs)
  assert changeset.errors[:last_name]
end
```

- [ ] **Add test: accepts accented and compound names**

```elixir
test "create_user/1 accepts accented and compound names" do
  attrs = %{
    email: "accent@example.com",
    first_name: "José",
    last_name: "O'Brien-Silva",
    birth_date: ~D[1990-01-01],
    biological_sex: :male,
    weight: "75.0",
    weight_unit: :kg,
    height: "175.0",
    height_unit: :cm
  }

  assert {:ok, user} = UserManagement.create_user(attrs)
  assert user.first_name == "José"
  assert user.last_name == "O'Brien-Silva"
end
```

- [ ] **Add test: accepts names with spaces**

```elixir
test "create_user/1 accepts names with spaces" do
  attrs = %{
    email: "space@example.com",
    first_name: "Ana Maria",
    last_name: "Da Silva",
    birth_date: ~D[1990-01-01],
    biological_sex: :male,
    weight: "75.0",
    weight_unit: :kg,
    height: "175.0",
    height_unit: :cm
  }

  assert {:ok, user} = UserManagement.create_user(attrs)
  assert user.first_name == "Ana Maria"
  assert user.last_name == "Da Silva"
end
```

### Step 1.2: Run tests to verify they fail

- [ ] **Run tests**

```bash
mix test test/drink_water/user_management_test.exs --trace
```

Expected: The "rejects" tests PASS (wrong — they should fail since no format validation exists yet). The "accepts" tests PASS. If the "rejects" tests pass, that means the inputs are rejected for other reasons — re-check the test data. If they fail as expected, proceed.

**IMPORTANT:** The "rejects" tests should FAIL because `changeset.errors[:first_name]` will be `nil` (no format error). If they unexpectedly pass, investigate before proceeding.

### Step 1.3: Implement name format validation

- [ ] **Add `validate_format` to user changeset**

In `lib/drink_water/user_management/user.ex`, add a module attribute for the name regex and two `validate_format` calls to the changeset:

```elixir
# Add after @max_age 99 (line 6):
@name_format ~r/^[\p{L}](?:[\p{L}'\s-]*[\p{L}'])?$/u
```

```elixir
# Add after validate_length(:last_name, ...) (line 44), before validate_number:
|> validate_format(:first_name, @name_format, message: "must contain only letters, spaces, hyphens, or apostrophes")
|> validate_format(:last_name, @name_format, message: "must contain only letters, spaces, hyphens, or apostrophes")
```

**Design note:** The `u` flag enables Unicode matching. `\p{L}` matches any Unicode letter (Latin, accented, Cyrillic, etc.) without including symbols like ©, ×, ÷ that raw byte ranges would allow. The regex allows:

- Start with any Unicode letter
- Middle can have letters, apostrophes, spaces, hyphens
- End with a letter or apostrophe
- Single-character letter names are allowed (min length is already enforced separately)

### Step 1.4: Run tests to verify they pass

- [ ] **Run all user management tests**

```bash
mix test test/drink_water/user_management_test.exs --trace
```

Expected: ALL tests pass, including existing ones.

### Step 1.5: Add controller-level test for validation error response

- [ ] **Add test to user controller**

```elixir
# In test/drink_water_web/controllers/user_controller_test.exs, inside describe "create user"
test "returns 422 when name contains invalid characters", %{conn: conn} do
  invalid_name_attrs = %{@create_attrs | first_name: "John123", last_name: "Doe<>"}
  conn = post(conn, ~p"/api/users", user: invalid_name_attrs)
  response = json_response(conn, 422)
  assert response["type"] == "https://www.drinkwater.com.br/validation-error"
  assert response["errors"]["first_name"]
  assert response["errors"]["last_name"]
end
```

### Step 1.6: Run controller test

- [ ] **Run controller tests**

```bash
mix test test/drink_water_web/controllers/user_controller_test.exs --trace
```

Expected: ALL tests pass.

### Step 1.7: Run full precommit and commit

- [ ] **Run precommit**

```bash
mix precommit
```

Expected: Clean compile, formatted, all tests pass.

- [ ] **Commit**

```bash
git add lib/drink_water/user_management/user.ex test/drink_water/user_management_test.exs test/drink_water_web/controllers/user_controller_test.exs
git commit -m "Add name format validation to reject numbers and special characters"
```

---

## Task 2: Separate Search Rate Limit

**Context:** Java has a lower rate limit for water intake search (20/min) vs CRUD (60/min) because search queries are heavier. Currently Phoenix uses a single 60/min limit for all water intake endpoints. The fix is idiomatic Phoenix: add a new pipeline and restructure the router scope.

**Files:**
- Modify: `lib/drink_water_web/router.ex:49-53`
- Test: `test/drink_water_web/plugs/rate_limiter_test.exs`

### Step 2.1: Write failing test for separate search rate limit

- [ ] **Add test in rate_limiter_test.exs**

```elixir
# In test/drink_water_web/plugs/rate_limiter_test.exs
describe "water intake search has separate rate limit" do
  test "search has lower limit than CRUD", %{conn: conn} do
    user = user_fixture()

    date_range = %{
      "start_date" => "2026-03-01T00:00:00Z",
      "end_date" => "2026-03-31T23:59:59Z"
    }

    # Exhaust search limit (20 requests)
    for _ <- 1..20 do
      conn = get(conn, ~p"/api/users/#{user.id}/water_intakes", date_range)
      assert conn.status == 200
    end

    # 21st search request should be rate limited
    conn = get(conn, ~p"/api/users/#{user.id}/water_intakes", date_range)
    assert conn.status == 429
  end
end
```

### Step 2.2: Run test to verify it fails

- [ ] **Run rate limiter tests**

```bash
mix test test/drink_water_web/plugs/rate_limiter_test.exs --trace
```

Expected: FAIL — search currently uses 60/min limit, so 21st request passes.

### Step 2.3: Implement separate search rate limit

- [ ] **Add pipeline and restructure router**

In `lib/drink_water_web/router.ex`, add a new pipeline and split the water intake scope:

```elixir
# Add after the :rate_limit_water_intake_api pipeline (after line 27):
pipeline :rate_limit_water_intake_search do
  plug DrinkWaterWeb.Plugs.RateLimiter,
    key_prefix: "waterintake-search",
    limit: 20
end
```

Then replace the water intake scope (lines 49-53) with two scopes:

```elixir
scope "/users/:user_id" do
  pipe_through :rate_limit_water_intake_api

  resources "/water_intakes", WaterIntakeController, except: [:new, :edit, :index]
end

scope "/users/:user_id" do
  pipe_through :rate_limit_water_intake_search

  get "/water_intakes", WaterIntakeController, :index
end
```

### Step 2.4: Run test to verify it passes

- [ ] **Run rate limiter tests**

```bash
mix test test/drink_water_web/plugs/rate_limiter_test.exs --trace
```

Expected: ALL tests pass.

### Step 2.5: Run full precommit and commit

- [ ] **Run precommit**

```bash
mix precommit
```

Expected: Clean compile, formatted, all tests pass.

- [ ] **Commit**

```bash
git add lib/drink_water_web/router.ex test/drink_water_web/plugs/rate_limiter_test.exs
git commit -m "Add separate lower rate limit for water intake search endpoint"
```

---

## Task 3: Sort Field and Direction for Water Intake Search

**Context:** Java supports sorting by `dateTimeUTC`, `volume`, or `id` in `ASC` or `DESC` direction. Phoenix hardcodes `order_by(desc: :date_time_utc, desc: :id)`. The fix uses Ecto's composable query design: add `sort_field` and `sort_direction` to the filter embedded_schema, validate them with `validate_inclusion/3`, and use them in query composition. The cursor encoding must also include the sort field so cursors are tied to a specific sort.

**Files:**
- Modify: `lib/drink_water/hydration_tracking/water_intake_filter.ex`
- Modify: `lib/drink_water/hydration_tracking.ex:19-36` (list_water_intakes, apply_cursor, build_page, encode/decode_cursor)
- Modify: `lib/drink_water_web/controllers/water_intake_controller.ex:10` (@filter_params)
- Test: `test/drink_water/hydration_tracking_test.exs`
- Test: `test/drink_water_web/controllers/water_intake_controller_test.exs`

### Step 3.1: Write failing context tests for sort

- [ ] **Add test: sort by volume ascending**

```elixir
# In test/drink_water/hydration_tracking_test.exs, inside describe "water_intakes"
test "list_water_intakes/2 sorts by volume ascending" do
  user = user_fixture()
  water_intake_fixture(user.id, %{date_time_utc: ~U[2026-03-14 10:00:00Z], volume: 500})
  water_intake_fixture(user.id, %{date_time_utc: ~U[2026-03-14 11:00:00Z], volume: 100})
  water_intake_fixture(user.id, %{date_time_utc: ~U[2026-03-14 12:00:00Z], volume: 300})

  params = Map.merge(@date_range, %{"sort_field" => "volume", "sort_direction" => "asc"})

  assert {:ok, %{entries: entries}} =
           HydrationTracking.list_water_intakes(user.id, params)

  volumes = Enum.map(entries, & &1.volume)
  assert volumes == [100, 300, 500]
end
```

- [ ] **Add test: sort by date_time_utc ascending (reverse default)**

```elixir
test "list_water_intakes/2 sorts by date_time_utc ascending" do
  user = user_fixture()
  water_intake_fixture(user.id, %{date_time_utc: ~U[2026-03-14 12:00:00Z]})
  water_intake_fixture(user.id, %{date_time_utc: ~U[2026-03-14 10:00:00Z]})
  water_intake_fixture(user.id, %{date_time_utc: ~U[2026-03-14 11:00:00Z]})

  params = Map.merge(@date_range, %{"sort_field" => "date_time_utc", "sort_direction" => "asc"})

  assert {:ok, %{entries: entries}} =
           HydrationTracking.list_water_intakes(user.id, params)

  times = Enum.map(entries, & &1.date_time_utc)
  assert times == [~U[2026-03-14 10:00:00Z], ~U[2026-03-14 11:00:00Z], ~U[2026-03-14 12:00:00Z]]
end
```

- [ ] **Add test: default sort is date_time_utc descending (existing behavior preserved)**

```elixir
test "list_water_intakes/2 defaults to date_time_utc descending" do
  user = user_fixture()
  water_intake_fixture(user.id, %{date_time_utc: ~U[2026-03-14 10:00:00Z]})
  water_intake_fixture(user.id, %{date_time_utc: ~U[2026-03-14 12:00:00Z]})
  water_intake_fixture(user.id, %{date_time_utc: ~U[2026-03-14 11:00:00Z]})

  assert {:ok, %{entries: entries}} =
           HydrationTracking.list_water_intakes(user.id, @date_range)

  times = Enum.map(entries, & &1.date_time_utc)
  assert times == [~U[2026-03-14 12:00:00Z], ~U[2026-03-14 11:00:00Z], ~U[2026-03-14 10:00:00Z]]
end
```

- [ ] **Add test: rejects invalid sort_field**

```elixir
test "list_water_intakes/2 rejects invalid sort_field" do
  user = user_fixture()
  params = Map.merge(@date_range, %{"sort_field" => "email"})
  assert {:error, %Ecto.Changeset{} = changeset} = HydrationTracking.list_water_intakes(user.id, params)
  assert changeset.errors[:sort_field]
end
```

- [ ] **Add test: rejects invalid sort_direction**

```elixir
test "list_water_intakes/2 rejects invalid sort_direction" do
  user = user_fixture()
  params = Map.merge(@date_range, %{"sort_direction" => "sideways"})
  assert {:error, %Ecto.Changeset{} = changeset} = HydrationTracking.list_water_intakes(user.id, params)
  assert changeset.errors[:sort_direction]
end
```

- [ ] **Add test: pagination with volume sort**

```elixir
test "list_water_intakes/2 paginates correctly with volume sort" do
  user = user_fixture()

  for {vol, i} <- [{300, 1}, {100, 2}, {500, 3}, {200, 4}] do
    water_intake_fixture(user.id, %{
      date_time_utc: DateTime.add(~U[2026-03-10 10:00:00Z], i * 3600, :second),
      volume: vol
    })
  end

  params = Map.merge(@date_range, %{"sort_field" => "volume", "sort_direction" => "asc", "size" => "2"})

  assert {:ok, %{entries: page1, next_cursor: cursor}} =
           HydrationTracking.list_water_intakes(user.id, params)

  assert length(page1) == 2
  assert Enum.map(page1, & &1.volume) == [100, 200]
  assert cursor != nil

  params2 = Map.merge(params, %{"cursor" => cursor})

  assert {:ok, %{entries: page2, next_cursor: cursor2}} =
           HydrationTracking.list_water_intakes(user.id, params2)

  assert length(page2) == 2
  assert Enum.map(page2, & &1.volume) == [300, 500]
  assert is_nil(cursor2)
end
```

### Step 3.2: Run tests to verify they fail

- [ ] **Run context tests**

```bash
mix test test/drink_water/hydration_tracking_test.exs --trace
```

Expected: New tests FAIL — `sort_field` and `sort_direction` are unknown fields.

### Step 3.3: Implement sort in WaterIntakeFilter

- [ ] **Add sort fields to embedded_schema**

In `lib/drink_water/hydration_tracking/water_intake_filter.ex`:

```elixir
# Add to embedded_schema (after cursor field, line 13):
field :sort_field, :string, default: "date_time_utc"
field :sort_direction, :string, default: "desc"
```

```elixir
# Update @cast_fields (line 17) to include the new fields:
@cast_fields [:start_date, :end_date, :min_volume, :max_volume, :cursor, :size, :sort_field, :sort_direction]
```

```elixir
# Add allowed values as module attributes (after @max_size):
@allowed_sort_fields ~w(date_time_utc volume id)
@allowed_sort_directions ~w(asc desc)
```

```elixir
# Add validations in changeset/1, after validate_length(:cursor, ...):
|> validate_inclusion(:sort_field, @allowed_sort_fields)
|> validate_inclusion(:sort_direction, @allowed_sort_directions)
```

### Step 3.4: Implement sort in HydrationTracking context

- [ ] **Update list_water_intakes to use dynamic sort**

In `lib/drink_water/hydration_tracking.ex`, replace lines 28-31 (the static order_by/limit/Repo.all block):

```elixir
entries =
  query
  |> apply_sort(filter)
  |> limit(^(filter.size + 1))
  |> Repo.all()

{page, next_cursor} = build_page(entries, filter)
{:ok, %{entries: page, next_cursor: next_cursor}}
```

- [ ] **Add apply_sort/2 function**

```elixir
# Add in the private functions section (before apply_date_filter):
defp apply_sort(query, %{sort_field: field, sort_direction: dir}) do
  sort_field = String.to_existing_atom(field)
  sort_dir = String.to_existing_atom(dir)

  order_by(query, [w], [{^sort_dir, field(w, ^sort_field)}, {^sort_dir, w.id}])
end
```

- [ ] **Update apply_cursor to be sort-aware**

Replace `apply_cursor/2` (lines 127-143) with a version that handles both ASC and DESC for any field:

```elixir
defp apply_cursor(query, %{cursor: nil}), do: {:ok, query}

defp apply_cursor(query, %{cursor: cursor, sort_field: field, sort_direction: dir}) do
  sort_field = String.to_existing_atom(field)

  case decode_cursor(cursor) do
    {:ok, cursor_value, cursor_id} ->
      filtered =
        if dir == "desc" do
          where(query, [w],
            field(w, ^sort_field) < ^cursor_value or
              (field(w, ^sort_field) == ^cursor_value and w.id < ^cursor_id)
          )
        else
          where(query, [w],
            field(w, ^sort_field) > ^cursor_value or
              (field(w, ^sort_field) == ^cursor_value and w.id > ^cursor_id)
          )
        end

      {:ok, filtered}

    :error ->
      {:error, :bad_request}
  end
end
```

- [ ] **Update build_page to receive the full filter**

Change `build_page/2` signature and cursor encoding:

```elixir
defp build_page(entries, %{size: size, sort_field: field} = _filter) when length(entries) > size do
  page = Enum.take(entries, size)
  last = List.last(page)
  sort_value = Map.get(last, String.to_existing_atom(field))
  {page, encode_cursor(sort_value, last.id)}
end

defp build_page(entries, _filter), do: {entries, nil}
```

- [ ] **Update encode_cursor to handle different value types**

Replace `encode_cursor/2`:

```elixir
defp encode_cursor(%DateTime{} = value, id) do
  "#{DateTime.to_iso8601(value)}|#{id}"
  |> Base.url_encode64(padding: false)
end

defp encode_cursor(value, id) do
  "#{value}|#{id}"
  |> Base.url_encode64(padding: false)
end
```

- [ ] **Update decode_cursor to handle integer values**

Replace `decode_cursor/1`:

```elixir
defp decode_cursor(cursor) do
  with {:ok, decoded} <- Base.url_decode64(cursor, padding: false),
       [value_str, id_str] <- String.split(decoded, "|", parts: 2),
       {id, ""} <- Integer.parse(id_str) do
    cursor_value = parse_cursor_value(value_str)

    if cursor_value do
      {:ok, cursor_value, id}
    else
      :error
    end
  else
    _ -> :error
  end
end

defp parse_cursor_value(value_str) do
  case DateTime.from_iso8601(value_str) do
    {:ok, datetime, _offset} -> datetime
    _ ->
      case Integer.parse(value_str) do
        {int, ""} -> int
        _ -> nil
      end
  end
end
```

- [ ] **Update the call site in list_water_intakes**

Update the `apply_cursor` call (around line 26) to pass the full filter:

```elixir
# Change:
|> apply_cursor(filter.cursor) do
# To:
|> apply_cursor(filter) do
```

### Step 3.5: Update controller to pass sort params

- [ ] **Add sort params to @filter_params**

In `lib/drink_water_web/controllers/water_intake_controller.ex`, line 10:

```elixir
# Change:
@filter_params ~w(start_date end_date min_volume max_volume cursor size)
# To:
@filter_params ~w(start_date end_date min_volume max_volume cursor size sort_field sort_direction)
```

### Step 3.6: Run context tests

- [ ] **Run context tests**

```bash
mix test test/drink_water/hydration_tracking_test.exs --trace
```

Expected: ALL tests pass (both new and existing).

### Step 3.7: Add controller-level test

- [ ] **Add test to water intake controller**

```elixir
# In test/drink_water_web/controllers/water_intake_controller_test.exs, inside describe "index"
test "sorts by volume ascending", %{conn: conn, user: user} do
  water_intake_fixture(user.id, %{date_time_utc: ~U[2026-03-14 10:00:00Z], volume: 500})
  water_intake_fixture(user.id, %{date_time_utc: ~U[2026-03-14 11:00:00Z], volume: 100})

  params = Map.merge(@date_range, %{"sort_field" => "volume", "sort_direction" => "asc"})
  conn = get(conn, ~p"/api/users/#{user.id}/water_intakes", params)
  response = json_response(conn, 200)
  volumes = Enum.map(response["data"], & &1["volume"])
  assert volumes == [100, 500]
end

test "returns 422 for invalid sort_field", %{conn: conn, user: user} do
  params = Map.merge(@date_range, %{"sort_field" => "email"})
  conn = get(conn, ~p"/api/users/#{user.id}/water_intakes", params)
  response = json_response(conn, 422)
  assert response["type"] == "https://www.drinkwater.com.br/validation-error"
  assert response["errors"]["sort_field"]
end
```

### Step 3.8: Run controller tests

- [ ] **Run controller tests**

```bash
mix test test/drink_water_web/controllers/water_intake_controller_test.exs --trace
```

Expected: ALL tests pass.

### Step 3.9: Run full precommit and commit

- [ ] **Run precommit**

```bash
mix precommit
```

Expected: Clean compile, formatted, all tests pass.

- [ ] **Commit**

```bash
git add lib/drink_water/hydration_tracking/water_intake_filter.ex lib/drink_water/hydration_tracking.ex lib/drink_water_web/controllers/water_intake_controller.ex test/drink_water/hydration_tracking_test.exs test/drink_water_web/controllers/water_intake_controller_test.exs
git commit -m "Add configurable sort field and direction to water intake search"
```

---

## Task 4: Idempotent User Delete

**Context:** Java's `DELETE /users` returns 204 even if the user doesn't exist — it's idempotent by design. Phoenix currently does a `get_user` → `delete_user` chain, returning 404 for missing users. The Elixir-idiomatic fix: add a `delete_user_by_id/1` function to the context that uses `Repo.delete_all` with a query (returns `{count, _}` — naturally idempotent).

**Files:**
- Modify: `lib/drink_water/user_management.ex`
- Modify: `lib/drink_water_web/controllers/user_controller.ex:36-41`
- Test: `test/drink_water/user_management_test.exs`
- Test: `test/drink_water_web/controllers/user_controller_test.exs`

### Step 4.1: Write failing context test

- [ ] **Add test: delete_user_by_id returns :ok for nonexistent user**

```elixir
# In test/drink_water/user_management_test.exs, inside describe "users"
test "delete_user_by_id/1 returns :ok for nonexistent user" do
  assert :ok = UserManagement.delete_user_by_id(0)
end
```

- [ ] **Add test: delete_user_by_id deletes existing user**

```elixir
test "delete_user_by_id/1 deletes an existing user" do
  user = user_fixture()
  assert :ok = UserManagement.delete_user_by_id(user.id)
  assert {:error, :not_found, :user} = UserManagement.get_user(user.id)
end
```

- [ ] **Add test: delete_user_by_id accepts string id**

```elixir
test "delete_user_by_id/1 accepts string id" do
  user = user_fixture()
  assert :ok = UserManagement.delete_user_by_id(to_string(user.id))
  assert {:error, :not_found, :user} = UserManagement.get_user(user.id)
end
```

- [ ] **Add test: delete_user_by_id returns :ok for non-integer string**

```elixir
test "delete_user_by_id/1 returns :ok for non-integer string id" do
  assert :ok = UserManagement.delete_user_by_id("abc")
end
```

- [ ] **Add test: delete_user_by_id cascades to alarm_settings and water_intakes**

```elixir
test "delete_user_by_id/1 cascades to alarm_settings and water_intakes" do
  user = user_fixture()
  alarm_settings_fixture(user)

  {:ok, _} =
    DrinkWater.HydrationTracking.create_water_intake(user.id, %{
      date_time_utc: ~U[2026-03-14 10:00:00Z],
      volume: 250,
      volume_unit: :ml
    })

  assert :ok = UserManagement.delete_user_by_id(user.id)

  assert {:error, :not_found, :alarm_settings} =
           UserManagement.get_alarm_settings_by_user(user.id)

  assert {:error, :not_found, :water_intake} =
           DrinkWater.HydrationTracking.get_water_intake(user.id, 0)
end
```

### Step 4.2: Run tests to verify they fail

- [ ] **Run context tests**

```bash
mix test test/drink_water/user_management_test.exs --trace
```

Expected: FAIL — `delete_user_by_id/1` is not defined.

### Step 4.3: Implement delete_user_by_id

- [ ] **Add function to UserManagement context**

In `lib/drink_water/user_management.ex`, add after `delete_user/1` (after line 105):

```elixir
@doc """
Deletes a user by ID. Idempotent — returns `:ok` whether the user
existed or not. Accepts integer or string ID.
"""
def delete_user_by_id(id) when is_integer(id) do
  User
  |> where(id: ^id)
  |> Repo.delete_all()

  :ok
end

def delete_user_by_id(id) when is_binary(id) do
  case Integer.parse(id) do
    {int_id, ""} -> delete_user_by_id(int_id)
    _ -> :ok
  end
end

def delete_user_by_id(_), do: :ok
```

### Step 4.4: Run context tests

- [ ] **Run context tests**

```bash
mix test test/drink_water/user_management_test.exs --trace
```

Expected: ALL tests pass.

### Step 4.5: Update controller to use idempotent delete

- [ ] **Replace delete action in UserController**

In `lib/drink_water_web/controllers/user_controller.ex`, replace the `delete/2` function (lines 36-41):

```elixir
def delete(conn, %{"id" => id}) do
  :ok = UserManagement.delete_user_by_id(id)
  send_resp(conn, :no_content, "")
end
```

### Step 4.6: Update controller test for idempotent behavior

- [ ] **Change the existing "delete returns 404" test**

In `test/drink_water_web/controllers/user_controller_test.exs`, replace the test in `describe "not found"` that says `"delete returns 404 in RFC 7807 format for nonexistent user"` (lines 178-186):

```elixir
test "delete returns 204 for nonexistent user (idempotent)", %{conn: conn} do
  conn = delete(conn, ~p"/api/users/0")
  assert response(conn, 204)
end
```

### Step 4.7: Run controller tests

- [ ] **Run controller tests**

```bash
mix test test/drink_water_web/controllers/user_controller_test.exs --trace
```

Expected: ALL tests pass.

### Step 4.8: Run full precommit and commit

- [ ] **Run precommit**

```bash
mix precommit
```

Expected: Clean compile, formatted, all tests pass.

- [ ] **Commit**

```bash
git add lib/drink_water/user_management.ex lib/drink_water_web/controllers/user_controller.ex test/drink_water/user_management_test.exs test/drink_water_web/controllers/user_controller_test.exs
git commit -m "Make user delete idempotent (204 for nonexistent users)"
```

---

## Post-Implementation: Update MIGRATION_ROADMAP.md

- [ ] **Add a Step 7.5 or note to Phase 3**

Add these items as completed under Phase 3 in `MIGRATION_ROADMAP.md`:

```markdown
- [x] Step 7a: Name format validation (letters, accents, apostrophes, hyphens, spaces only)
- [x] Step 7b: Separate search rate limit (20/min vs 60/min for CRUD)
- [x] Step 7c: Configurable sort field/direction in water intake search
- [x] Step 7d: Idempotent user delete (204 for nonexistent users)
```
