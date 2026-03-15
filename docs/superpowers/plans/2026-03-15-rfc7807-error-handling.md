# RFC 7807 Error Handling Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace generic error responses with full RFC 7807 Problem Details — specific `type` URIs, human-readable `detail` messages via Gettext, and `instance` paths for every API error.

**Architecture:** Centralized error catalog in `ProblemDetail` module, thin `FallbackController` dispatcher, unified `ErrorJSON` view. Contexts return enriched error tuples `{:error, :not_found, :resource}` and `{:error, :conflict, :resource}`. Gettext domain `errors` for i18n-ready messages.

**Tech Stack:** Phoenix 1.8, Ecto 3.13, Gettext 0.26, Elixir 1.19

**Spec:** `docs/superpowers/specs/2026-03-15-rfc7807-error-handling-design.md`

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `lib/drink_water_web/problem_detail.ex` | Rewrite | Error catalog + RFC 7807 builder + Gettext |
| `lib/drink_water_web/controllers/error_json.ex` | Rewrite | Unified error view (FallbackController + Endpoint) |
| `lib/drink_water_web/controllers/fallback_controller.ex` | Rewrite | Pattern match error tuples → ProblemDetail |
| `lib/drink_water_web/controllers/changeset_json.ex` | Delete | Absorbed by ErrorJSON |
| `lib/drink_water_web/plugs/rate_limiter.ex` | Modify | Use ProblemDetail instead of manual map |
| `lib/drink_water/user_management.ex` | Modify | Enriched error tuples + conflict detection |
| `lib/drink_water/hydration_tracking.ex` | Modify | Enriched error tuples + conflict detection |
| `test/drink_water_web/controllers/problem_detail_test.exs` | Rewrite | Test every catalog entry |
| `test/drink_water_web/controllers/error_json_test.exs` | Rewrite | Test both render paths |
| `test/drink_water_web/controllers/user_controller_test.exs` | Modify | Validate 5 RFC 7807 fields |
| `test/drink_water_web/controllers/alarm_settings_controller_test.exs` | Modify | Validate 5 RFC 7807 fields |
| `test/drink_water_web/controllers/water_intake_controller_test.exs` | Modify | Validate 5 RFC 7807 fields |
| `test/drink_water_web/plugs/rate_limiter_test.exs` | Modify | Validate type, detail, instance |
| `test/drink_water/user_management_test.exs` | Modify | Test enriched tuples + conflict |
| `test/drink_water/hydration_tracking_test.exs` | Modify | Test enriched tuples + conflict |

---

## Chunk 1: ProblemDetail Module + ErrorJSON + Gettext

### Task 1: Rewrite ProblemDetail with error catalog and Gettext

**Files:**
- Rewrite: `lib/drink_water_web/problem_detail.ex`
- Test: `test/drink_water_web/controllers/problem_detail_test.exs`

- [ ] **Step 1: Write failing tests for `build/1` (generic 500)**

```elixir
# test/drink_water_web/controllers/problem_detail_test.exs
defmodule DrinkWaterWeb.ProblemDetailTest do
  use DrinkWaterWeb.ConnCase, async: true

  alias DrinkWaterWeb.ProblemDetail

  defp conn_with_path(path) do
    build_conn(:get, path)
  end

  describe "build/1 (generic 500)" do
    test "returns internal server error with all RFC 7807 fields" do
      result = ProblemDetail.build(conn_with_path("/api/users"))

      assert result == %{
               type: "https://www.drinkwater.com.br/internal-server-error",
               title: "Internal Server Error",
               status: 500,
               detail: "An unexpected error occurred. Please try again later or contact support.",
               instance: "/api/users"
             }
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/drink_water_web/controllers/problem_detail_test.exs --seed 0`
Expected: FAIL — current `ProblemDetail.build/1` expects `%Plug.Conn{}` with status set, new signature takes conn only.

- [ ] **Step 3: Write failing tests for `build/2` (single-key catalog lookup)**

Add to the same test file:

```elixir
describe "build/2 (single-key catalog)" do
  test "bad_request returns 400 with specific type and detail" do
    result = ProblemDetail.build(conn_with_path("/api/users"), :bad_request)

    assert result == %{
             type: "https://www.drinkwater.com.br/invalid-argument",
             title: "Bad Request",
             status: 400,
             detail: "An invalid argument was provided.",
             instance: "/api/users"
           }
  end

  test "parsing_error returns 400 with parsing-error type" do
    result = ProblemDetail.build(conn_with_path("/api/users"), :parsing_error)

    assert result == %{
             type: "https://www.drinkwater.com.br/parsing-error",
             title: "Bad Request",
             status: 400,
             detail: "Unable to process the request. Please check that your data is properly formatted.",
             instance: "/api/users"
           }
  end

  test "rate_limit_exceeded returns 429" do
    result = ProblemDetail.build(conn_with_path("/api/users/1/water_intakes"), :rate_limit_exceeded)

    assert result == %{
             type: "https://www.drinkwater.com.br/rate-limit-exceeded",
             title: "Too Many Requests",
             status: 429,
             detail: "Too many requests. Please wait before trying again.",
             instance: "/api/users/1/water_intakes"
           }
  end
end
```

- [ ] **Step 4: Write failing tests for `build/3` (composite-key catalog lookup)**

Add to the same test file:

```elixir
describe "build/3 (composite-key catalog)" do
  test "not_found user returns 404 with user-not-found type" do
    result = ProblemDetail.build(conn_with_path("/api/users/999"), :not_found, :user)

    assert result == %{
             type: "https://www.drinkwater.com.br/user-not-found",
             title: "Not Found",
             status: 404,
             detail: "The requested user account was not found.",
             instance: "/api/users/999"
           }
  end

  test "not_found alarm_settings" do
    result = ProblemDetail.build(conn_with_path("/api/users/1/alarm_settings"), :not_found, :alarm_settings)

    assert result == %{
             type: "https://www.drinkwater.com.br/alarm-settings-not-found",
             title: "Not Found",
             status: 404,
             detail: "The requested alarm settings were not found.",
             instance: "/api/users/1/alarm_settings"
           }
  end

  test "not_found water_intake" do
    result = ProblemDetail.build(conn_with_path("/api/users/1/water_intakes/99"), :not_found, :water_intake)

    assert result == %{
             type: "https://www.drinkwater.com.br/waterintake-not-found",
             title: "Not Found",
             status: 404,
             detail: "The requested water intake record was not found.",
             instance: "/api/users/1/water_intakes/99"
           }
  end

  test "conflict user returns 409 with user-already-exists type" do
    result = ProblemDetail.build(conn_with_path("/api/users"), :conflict, :user)

    assert result == %{
             type: "https://www.drinkwater.com.br/user-already-exists",
             title: "Conflict",
             status: 409,
             detail: "A user with this email address already exists.",
             instance: "/api/users"
           }
  end

  test "conflict alarm_settings" do
    result = ProblemDetail.build(conn_with_path("/api/users/1/alarm_settings"), :conflict, :alarm_settings)

    assert result == %{
             type: "https://www.drinkwater.com.br/alarm-settings-already-exists",
             title: "Conflict",
             status: 409,
             detail: "Alarm settings already exist for this user.",
             instance: "/api/users/1/alarm_settings"
           }
  end

  test "conflict water_intake" do
    result = ProblemDetail.build(conn_with_path("/api/users/1/water_intakes"), :conflict, :water_intake)

    assert result == %{
             type: "https://www.drinkwater.com.br/waterintake-duplicate-datetime",
             title: "Conflict",
             status: 409,
             detail: "A water intake record already exists for the specified date and time.",
             instance: "/api/users/1/water_intakes"
           }
  end
end
```

- [ ] **Step 5: Write failing test for `from_changeset/2`**

Add to the same test file:

```elixir
describe "from_changeset/2" do
  test "returns 422 with validation errors" do
    changeset =
      %DrinkWater.UserManagement.User{}
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.add_error(:email, "can't be blank")
      |> Ecto.Changeset.add_error(:first_name, "is too short")

    result = ProblemDetail.from_changeset(conn_with_path("/api/users"), changeset)

    assert result.type == "https://www.drinkwater.com.br/validation-error"
    assert result.title == "Unprocessable Content"
    assert result.status == 422
    assert result.detail == "One or more fields are invalid. Please correct them and try again."
    assert result.instance == "/api/users"
    assert result.errors[:email] == ["can't be blank"]
    assert result.errors[:first_name] == ["is too short"]
  end

  test "translates error message placeholders" do
    changeset =
      %DrinkWater.UserManagement.User{}
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.add_error(:first_name, "should be at least %{count} character(s)",
        count: 2,
        validation: :length,
        kind: :min
      )

    result = ProblemDetail.from_changeset(conn_with_path("/api/users"), changeset)
    assert result.errors[:first_name] == ["should be at least 2 character(s)"]
  end
end
```

- [ ] **Step 6: Run all ProblemDetail tests to verify they fail**

Run: `mix test test/drink_water_web/controllers/problem_detail_test.exs --seed 0`
Expected: All tests FAIL.

- [ ] **Step 7: Implement ProblemDetail module**

```elixir
# lib/drink_water_web/problem_detail.ex
defmodule DrinkWaterWeb.ProblemDetail do
  @moduledoc """
  Builds RFC 7807 Problem Detail responses.

  See: https://www.rfc-editor.org/rfc/rfc7807
  """

  use Gettext, backend: DrinkWaterWeb.Gettext

  @type_base_url "https://www.drinkwater.com.br"

  @error_catalog %{
    {:not_found, :user} => %{
      status: 404,
      slug: "user-not-found",
      message: "The requested user account was not found."
    },
    {:not_found, :alarm_settings} => %{
      status: 404,
      slug: "alarm-settings-not-found",
      message: "The requested alarm settings were not found."
    },
    {:not_found, :water_intake} => %{
      status: 404,
      slug: "waterintake-not-found",
      message: "The requested water intake record was not found."
    },
    {:conflict, :user} => %{
      status: 409,
      slug: "user-already-exists",
      message: "A user with this email address already exists."
    },
    {:conflict, :alarm_settings} => %{
      status: 409,
      slug: "alarm-settings-already-exists",
      message: "Alarm settings already exist for this user."
    },
    {:conflict, :water_intake} => %{
      status: 409,
      slug: "waterintake-duplicate-datetime",
      message: "A water intake record already exists for the specified date and time."
    },
    :bad_request => %{
      status: 400,
      slug: "invalid-argument",
      message: "An invalid argument was provided."
    },
    :parsing_error => %{
      status: 400,
      slug: "parsing-error",
      message: "Unable to process the request. Please check that your data is properly formatted."
    },
    :rate_limit_exceeded => %{
      status: 429,
      slug: "rate-limit-exceeded",
      message: "Too many requests. Please wait before trying again."
    },
    :validation_error => %{
      status: 422,
      slug: "validation-error",
      message: "One or more fields are invalid. Please correct them and try again."
    },
    :internal_server_error => %{
      status: 500,
      slug: "internal-server-error",
      message: "An unexpected error occurred. Please try again later or contact support."
    }
  }

  @doc """
  Builds a generic 500 Problem Detail. Used by Endpoint render_errors.
  """
  def build(%Plug.Conn{} = conn) do
    build_from_entry(conn, @error_catalog[:internal_server_error])
  end

  @doc """
  Builds a Problem Detail from a single-key catalog entry.
  """
  def build(%Plug.Conn{} = conn, error_key) when is_atom(error_key) do
    build_from_entry(conn, Map.fetch!(@error_catalog, error_key))
  end

  @doc """
  Builds a Problem Detail from a composite-key catalog entry.
  """
  def build(%Plug.Conn{} = conn, category, resource)
      when is_atom(category) and is_atom(resource) do
    build_from_entry(conn, Map.fetch!(@error_catalog, {category, resource}))
  end

  @doc """
  Builds a 422 Problem Detail with field-level validation errors from a changeset.
  """
  def from_changeset(%Plug.Conn{} = conn, %Ecto.Changeset{} = changeset) do
    entry = @error_catalog[:validation_error]

    build_from_entry(conn, entry)
    |> Map.put(:errors, translate_errors(changeset))
  end

  defp build_from_entry(conn, entry) do
    %{
      type: "#{@type_base_url}/#{entry.slug}",
      title: Plug.Conn.Status.reason_phrase(entry.status),
      status: entry.status,
      detail: dgettext("errors", entry.message),
      instance: conn.request_path
    }
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
```

- [ ] **Step 8: Run ProblemDetail tests to verify they pass**

Run: `mix test test/drink_water_web/controllers/problem_detail_test.exs --seed 0`
Expected: All PASS.

- [ ] **Step 9: Commit**

```bash
git add lib/drink_water_web/problem_detail.ex test/drink_water_web/controllers/problem_detail_test.exs
git commit -m "feat: rewrite ProblemDetail with error catalog and Gettext"
```

### Task 2: Rewrite ErrorJSON as unified error view

**Files:**
- Rewrite: `lib/drink_water_web/controllers/error_json.ex`
- Test: `test/drink_water_web/controllers/error_json_test.exs`

- [ ] **Step 1: Write failing tests for ErrorJSON**

```elixir
# test/drink_water_web/controllers/error_json_test.exs
defmodule DrinkWaterWeb.ErrorJSONTest do
  use DrinkWaterWeb.ConnCase, async: true

  alias DrinkWaterWeb.ErrorJSON

  describe "error/1 (FallbackController path)" do
    test "returns the problem map as-is" do
      problem = %{type: "test", title: "Test", status: 400, detail: "test", instance: "/test"}
      assert ErrorJSON.error(%{problem: problem}) == problem
    end
  end

  describe "render/2 (Endpoint render_errors path)" do
    test "returns generic 500 for unknown exceptions" do
      conn = build_conn(:get, "/api/users")
      result = ErrorJSON.render("500.json", %{conn: conn, reason: %RuntimeError{message: "boom"}})

      assert result.type == "https://www.drinkwater.com.br/internal-server-error"
      assert result.status == 500
      assert result.instance == "/api/users"
    end

    test "returns parsing-error for Plug.Parsers.ParseError" do
      conn = build_conn(:post, "/api/users")
      reason = %Plug.Parsers.ParseError{exception: %Jason.DecodeError{data: ""}}
      result = ErrorJSON.render("400.json", %{conn: conn, reason: reason})

      assert result.type == "https://www.drinkwater.com.br/parsing-error"
      assert result.status == 400
      assert result.instance == "/api/users"
    end

    test "returns invalid-argument for Phoenix.ActionClauseError" do
      conn = build_conn(:post, "/api/users")
      reason = %Phoenix.ActionClauseError{args: []}
      result = ErrorJSON.render("400.json", %{conn: conn, reason: reason})

      assert result.type == "https://www.drinkwater.com.br/invalid-argument"
      assert result.status == 400
      assert result.instance == "/api/users"
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/drink_water_web/controllers/error_json_test.exs --seed 0`
Expected: FAIL.

- [ ] **Step 3: Implement ErrorJSON**

```elixir
# lib/drink_water_web/controllers/error_json.ex
defmodule DrinkWaterWeb.ErrorJSON do
  alias DrinkWaterWeb.ProblemDetail

  @doc "Called by FallbackController — returns the pre-built problem map."
  def error(%{problem: problem}), do: problem

  @doc "Called by Endpoint render_errors — dispatches by exception type."
  def render(_template, %{conn: conn, reason: %Plug.Parsers.ParseError{}}) do
    ProblemDetail.build(conn, :parsing_error)
  end

  def render(_template, %{conn: conn, reason: %Phoenix.ActionClauseError{}}) do
    ProblemDetail.build(conn, :bad_request)
  end

  def render(_template, %{conn: conn}) do
    ProblemDetail.build(conn)
  end
end
```

- [ ] **Step 4: Run ErrorJSON tests to verify they pass**

Run: `mix test test/drink_water_web/controllers/error_json_test.exs --seed 0`
Expected: All PASS.

- [ ] **Step 5: Delete ChangesetJSON**

```bash
rm lib/drink_water_web/controllers/changeset_json.ex
```

- [ ] **Step 6: Commit**

```bash
git add lib/drink_water_web/controllers/error_json.ex
git rm lib/drink_water_web/controllers/changeset_json.ex
git commit -m "feat: rewrite ErrorJSON as unified error view, remove ChangesetJSON"
```

### Task 3: Rewrite FallbackController

**Files:**
- Rewrite: `lib/drink_water_web/controllers/fallback_controller.ex`

- [ ] **Step 1: Implement FallbackController**

```elixir
# lib/drink_water_web/controllers/fallback_controller.ex
defmodule DrinkWaterWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses
  using RFC 7807 Problem Details.
  """
  use DrinkWaterWeb, :controller

  alias DrinkWaterWeb.ProblemDetail

  def call(conn, {:error, :not_found, resource}) when is_atom(resource) do
    conn
    |> put_problem_content_type()
    |> put_status(:not_found)
    |> put_view(json: DrinkWaterWeb.ErrorJSON)
    |> render(:error, problem: ProblemDetail.build(conn, :not_found, resource))
  end

  def call(conn, {:error, :conflict, resource}) when is_atom(resource) do
    conn
    |> put_problem_content_type()
    |> put_status(:conflict)
    |> put_view(json: DrinkWaterWeb.ErrorJSON)
    |> render(:error, problem: ProblemDetail.build(conn, :conflict, resource))
  end

  def call(conn, {:error, :bad_request}) do
    conn
    |> put_problem_content_type()
    |> put_status(:bad_request)
    |> put_view(json: DrinkWaterWeb.ErrorJSON)
    |> render(:error, problem: ProblemDetail.build(conn, :bad_request))
  end

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_problem_content_type()
    |> put_status(:unprocessable_entity)
    |> put_view(json: DrinkWaterWeb.ErrorJSON)
    |> render(:error, problem: ProblemDetail.from_changeset(conn, changeset))
  end

  defp put_problem_content_type(conn) do
    put_resp_content_type(conn, "application/problem+json")
  end
end
```

- [ ] **Step 2: Run full test suite to check for regressions**

Run: `mix test --seed 0`
Expected: Some tests may fail due to contexts still returning old tuples. That's expected — we fix those in Chunk 2.

- [ ] **Step 3: Commit**

```bash
git add lib/drink_water_web/controllers/fallback_controller.ex
git commit -m "feat: rewrite FallbackController with enriched error tuple handlers"
```

### Task 4: Add Gettext messages

**Files:**
- Modify: `priv/gettext/errors.pot`
- Modify: `priv/gettext/en/LC_MESSAGES/errors.po`

- [ ] **Step 1: Run gettext extract to pick up dgettext calls from ProblemDetail**

Run: `mix gettext.extract --merge`
Expected: New messages appear in `errors.pot` and `errors.po`.

- [ ] **Step 2: Verify new messages were added**

Run: `grep -c "msgid" priv/gettext/errors.pot`
Expected: Count increased by 11 (the catalog messages).

- [ ] **Step 3: Commit**

```bash
git add priv/gettext/errors.pot priv/gettext/en/LC_MESSAGES/errors.po
git commit -m "feat: add RFC 7807 error messages to Gettext catalog"
```

---

## Chunk 2: Context Changes (enriched tuples + conflict detection)

### Task 5: Enrich UserManagement error tuples

**Files:**
- Modify: `lib/drink_water/user_management.ex`
- Modify: `test/drink_water/user_management_test.exs`

- [ ] **Step 1: Write failing test for enriched not_found tuple**

Add to `test/drink_water/user_management_test.exs` in the existing `get_user/1` describe block:

```elixir
test "get_user/1 returns {:error, :not_found, :user} for non-existent user" do
  assert {:error, :not_found, :user} = UserManagement.get_user(0)
end

test "get_user/1 returns {:error, :not_found, :user} for non-integer id" do
  assert {:error, :not_found, :user} = UserManagement.get_user("abc")
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/drink_water/user_management_test.exs --seed 0`
Expected: FAIL — current returns `{:error, :not_found}` (2-tuple).

- [ ] **Step 3: Update `get_user/1` in UserManagement context**

In `lib/drink_water/user_management.ex`, change all `{:error, :not_found}` returns in `get_user` to `{:error, :not_found, :user}`:

```elixir
def get_user(id) when is_integer(id) do
  case Repo.get(User, id) do
    nil -> {:error, :not_found, :user}
    user -> {:ok, user}
  end
end

def get_user(id) when is_binary(id) do
  case Integer.parse(id) do
    {int_id, ""} -> get_user(int_id)
    _ -> {:error, :not_found, :user}
  end
end

def get_user(_), do: {:error, :not_found, :user}
```

- [ ] **Step 4: Update `get_alarm_settings_by_user/1`**

```elixir
def get_alarm_settings_by_user(user_id) do
  case Repo.get_by(AlarmSettings, user_id: user_id) do
    nil -> {:error, :not_found, :alarm_settings}
    alarm_settings -> {:ok, alarm_settings}
  end
end
```

- [ ] **Step 5: Write failing test for conflict detection on create_user**

Add to `test/drink_water/user_management_test.exs`:

```elixir
test "create_user/1 returns {:error, :conflict, :user} for duplicate email" do
  user = user_fixture()
  duplicate_attrs = %{
    email: user.email,
    first_name: "Jane",
    last_name: "Doe",
    birth_date: ~D[1990-05-15],
    biological_sex: :female,
    weight: "65.0",
    weight_unit: :kg,
    height: "165.0",
    height_unit: :cm
  }

  assert {:error, :conflict, :user} = UserManagement.create_user(duplicate_attrs)
end
```

- [ ] **Step 6: Run test to verify it fails**

Run: `mix test test/drink_water/user_management_test.exs --seed 0`
Expected: FAIL — current returns `{:error, %Ecto.Changeset{}}`.

- [ ] **Step 7: Add conflict detection to `create_user/1`**

```elixir
def create_user(attrs) do
  %User{}
  |> User.changeset(attrs)
  |> Repo.insert()
  |> maybe_conflict(:user, :email)
end
```

Add a private helper at the bottom of the module:

```elixir
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
```

- [ ] **Step 8: Add conflict detection to `create_alarm_settings/2`**

```elixir
def create_alarm_settings(%User{} = user, attrs) do
  user
  |> Ecto.build_assoc(:alarm_settings)
  |> AlarmSettings.changeset(attrs)
  |> Repo.insert()
  |> maybe_conflict(:alarm_settings, :user_id)
end
```

- [ ] **Step 9: Write failing test for alarm_settings conflict**

Add to `test/drink_water/user_management_test.exs`:

```elixir
test "create_alarm_settings/2 returns {:error, :conflict, :alarm_settings} for duplicate" do
  user = user_fixture()
  alarm_settings_fixture(user: user)

  assert {:error, :conflict, :alarm_settings} =
           UserManagement.create_alarm_settings(user, %{
             goal: 2000,
             interval_minutes: 60,
             daily_start_time: ~T[08:00:00],
             daily_end_time: ~T[20:00:00]
           })
end
```

- [ ] **Step 10: Run UserManagement tests**

Run: `mix test test/drink_water/user_management_test.exs --seed 0`
Expected: All PASS. Fix any existing tests that expected `{:error, :not_found}` — update them to `{:error, :not_found, :user}` or `{:error, :not_found, :alarm_settings}`.

- [ ] **Step 11: Commit**

```bash
git add lib/drink_water/user_management.ex test/drink_water/user_management_test.exs
git commit -m "feat: enrich UserManagement error tuples with resource and conflict detection"
```

### Task 6: Enrich HydrationTracking error tuples

**Files:**
- Modify: `lib/drink_water/hydration_tracking.ex`
- Modify: `test/drink_water/hydration_tracking_test.exs`

- [ ] **Step 1: Write failing test for enriched not_found tuple**

Add to `test/drink_water/hydration_tracking_test.exs`:

```elixir
test "get_water_intake/2 returns {:error, :not_found, :water_intake} when not found" do
  user = user_fixture()
  assert {:error, :not_found, :water_intake} = HydrationTracking.get_water_intake(user.id, 0)
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/drink_water/hydration_tracking_test.exs --seed 0`
Expected: FAIL — current returns `{:error, :not_found}`.

- [ ] **Step 3: Update `get_water_intake/2`**

```elixir
def get_water_intake(user_id, id) do
  case Repo.get_by(WaterIntake, id: id, user_id: user_id) do
    nil -> {:error, :not_found, :water_intake}
    water_intake -> {:ok, water_intake}
  end
end
```

- [ ] **Step 4: Write failing test for conflict detection on create**

```elixir
test "create_water_intake/2 returns {:error, :conflict, :water_intake} for duplicate datetime" do
  user = user_fixture()
  datetime = ~U[2024-08-14 10:00:00Z]

  {:ok, _} = HydrationTracking.create_water_intake(user.id, %{
    date_time_utc: datetime,
    volume: 250,
    volume_unit: :ml
  })

  assert {:error, :conflict, :water_intake} =
           HydrationTracking.create_water_intake(user.id, %{
             date_time_utc: datetime,
             volume: 300,
             volume_unit: :ml
           })
end
```

- [ ] **Step 5: Add conflict detection to `create_water_intake/2` and `update_water_intake/2`**

```elixir
def create_water_intake(user_id, attrs) do
  %WaterIntake{user_id: user_id}
  |> WaterIntake.changeset(attrs)
  |> Repo.insert()
  |> maybe_conflict(:water_intake)
end

def update_water_intake(%WaterIntake{} = water_intake, attrs) do
  water_intake
  |> WaterIntake.changeset(attrs)
  |> Repo.update()
  |> maybe_conflict(:water_intake)
end
```

Add the private helper (similar pattern to UserManagement but checks `:user_id_date_time_utc` or the constraint name):

```elixir
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
    _ -> false
  end)
end
```

- [ ] **Step 6: Run HydrationTracking tests**

Run: `mix test test/drink_water/hydration_tracking_test.exs --seed 0`
Expected: All PASS. Fix any existing tests that expected `{:error, :not_found}` — update to `{:error, :not_found, :water_intake}`.

- [ ] **Step 7: Commit**

```bash
git add lib/drink_water/hydration_tracking.ex test/drink_water/hydration_tracking_test.exs
git commit -m "feat: enrich HydrationTracking error tuples with resource and conflict detection"
```

---

## Chunk 3: RateLimiter + Controller Tests + Full Suite

### Task 7: Update RateLimiter plug

**Files:**
- Modify: `lib/drink_water_web/plugs/rate_limiter.ex`
- Modify: `test/drink_water_web/plugs/rate_limiter_test.exs`

- [ ] **Step 1: Write failing test for RFC 7807 fields in 429 response**

Update the existing rate limiter test to check all 5 fields. In `test/drink_water_web/plugs/rate_limiter_test.exs`, find the test that checks the 429 response body and update:

```elixir
test "returns 429 with RFC 7807 problem detail when rate limit is exceeded", %{conn: conn} do
  # exhaust the limit
  for _ <- 1..31 do
    conn
    |> Map.put(:params, %{"user_id" => "1"})
    |> RateLimiter.call(@user_opts)
  end

  result =
    conn
    |> Map.put(:params, %{"user_id" => "1"})
    |> RateLimiter.call(@user_opts)

  body = Jason.decode!(result.resp_body)
  assert result.status == 429
  assert body["type"] == "https://www.drinkwater.com.br/rate-limit-exceeded"
  assert body["title"] == "Too Many Requests"
  assert body["status"] == 429
  assert body["detail"] == "Too many requests. Please wait before trying again."
  assert body["instance"] != nil
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/drink_water_web/plugs/rate_limiter_test.exs --seed 0`
Expected: FAIL — current response has `type: "about:blank"`.

- [ ] **Step 3: Update RateLimiter to use ProblemDetail**

In `lib/drink_water_web/plugs/rate_limiter.ex`, replace the deny branch:

```elixir
{:deny, retry_after_ms} ->
  retry_after = div(retry_after_ms, 1000) |> max(1)

  conn
  |> put_resp_content_type("application/problem+json")
  |> put_resp_header("retry-after", Integer.to_string(retry_after))
  |> send_resp(429, Jason.encode!(ProblemDetail.build(conn, :rate_limit_exceeded)))
  |> halt()
```

Update the alias at the top of the module to use the new ProblemDetail (it should already be aliased).

- [ ] **Step 4: Run RateLimiter tests**

Run: `mix test test/drink_water_web/plugs/rate_limiter_test.exs --seed 0`
Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/drink_water_web/plugs/rate_limiter.ex test/drink_water_web/plugs/rate_limiter_test.exs
git commit -m "feat: update RateLimiter to use ProblemDetail for 429 responses"
```

### Task 8: Update controller tests for full RFC 7807 validation

**Files:**
- Modify: `test/drink_water_web/controllers/user_controller_test.exs`
- Modify: `test/drink_water_web/controllers/alarm_settings_controller_test.exs`
- Modify: `test/drink_water_web/controllers/water_intake_controller_test.exs`

- [ ] **Step 1: Update UserControllerTest error assertions**

In `test/drink_water_web/controllers/user_controller_test.exs`, update all error response assertions to check all 5 RFC 7807 fields. For example, the 404 test:

```elixir
test "show returns 404 in RFC 7807 format for nonexistent user", %{conn: conn} do
  conn = get(conn, ~p"/api/users/0")
  assert {"content-type", "application/problem+json; charset=utf-8"} in conn.resp_headers
  response = json_response(conn, 404)
  assert response["type"] == "https://www.drinkwater.com.br/user-not-found"
  assert response["title"] == "Not Found"
  assert response["status"] == 404
  assert response["detail"] == "The requested user account was not found."
  assert response["instance"] == "/api/users/0"
end
```

Update the 422 validation error tests:

```elixir
test "renders errors in RFC 7807 format when data is invalid", %{conn: conn} do
  conn = post(conn, ~p"/api/users", user: @invalid_attrs)
  response = json_response(conn, 422)
  assert response["type"] == "https://www.drinkwater.com.br/validation-error"
  assert response["title"] == "Unprocessable Content"
  assert response["status"] == 422
  assert response["detail"] == "One or more fields are invalid. Please correct them and try again."
  assert response["instance"] == "/api/users"
  assert response["errors"] != %{}
end
```

Add a 409 conflict test:

```elixir
test "returns 409 when creating user with duplicate email", %{conn: conn} do
  post(conn, ~p"/api/users", user: @create_attrs)
  conn = post(conn, ~p"/api/users", user: @create_attrs)
  response = json_response(conn, 409)
  assert response["type"] == "https://www.drinkwater.com.br/user-already-exists"
  assert response["title"] == "Conflict"
  assert response["status"] == 409
  assert response["detail"] == "A user with this email address already exists."
  assert response["instance"] == "/api/users"
end
```

- [ ] **Step 2: Update AlarmSettingsControllerTest similarly**

Update 404 and 422 tests with all 5 fields. Add 409 conflict test for duplicate alarm_settings.

- [ ] **Step 3: Update WaterIntakeControllerTest similarly**

Update 404, 422, and 400 tests with all 5 fields. Add 409 conflict test for duplicate datetime.

- [ ] **Step 4: Run all controller tests**

Run: `mix test test/drink_water_web/controllers/ --seed 0`
Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add test/drink_water_web/controllers/user_controller_test.exs test/drink_water_web/controllers/alarm_settings_controller_test.exs test/drink_water_web/controllers/water_intake_controller_test.exs
git commit -m "test: update controller tests to validate all 5 RFC 7807 fields"
```

### Task 9: Run full test suite and verify

- [ ] **Step 1: Run the full test suite**

Run: `mix test --seed 0`
Expected: All tests PASS, 0 failures.

- [ ] **Step 2: Run mix precommit**

Run: `mix precommit`
Expected: All checks PASS.

- [ ] **Step 3: Final commit if any remaining changes**

```bash
git status
# if any unstaged changes remain, stage and commit
```
