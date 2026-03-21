# ProblemDetail Struct Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract a generic, zero-dependency RFC 9457 `ProblemDetail` struct from the project-specific `DrinkWaterWeb.ProblemDetail`, creating a reusable Layer 1 module and a project-specific Layer 2 `ErrorCatalog`.

**Architecture:** Layer 1 (`lib/problem_detail.ex`) is a pure struct with pipe-friendly API and `JSON.Encoder` protocol — zero external deps. Layer 2 (`lib/drink_water_web/error_catalog.ex`) wraps Layer 1 with the project's error catalog, Gettext i18n, and `Plug.Conn` integration.

**Tech Stack:** Elixir 1.18+, `JSON` native encoder, Phoenix 1.8, Ecto (Layer 2 only)

**Spec:** `docs/superpowers/specs/2026-03-21-problem-detail-struct-design.md`

---

### Task 0: Switch Phoenix json_library from Jason to JSON (Elixir 1.18+ native)

**Files:**
- Modify: `config/config.exs:63`
- Modify: `lib/drink_water_web/plugs/rate_limiter.ex:57`
- Modify: `test/drink_water_web/controllers/user_controller_test.exs:207,226`

**Why:** Phoenix uses `config :phoenix, :json_library, Jason` to serialize all controller responses. The new `ProblemDetail` struct implements `JSON.Encoder` (Elixir 1.18+ native), not `Jason.Encoder`. Switching the global json_library to `JSON` ensures Phoenix serializes structs using our protocol implementation. This aligns with Elixir 1.18+'s direction where `JSON` is the standard.

- [ ] **Step 1: Run full test suite to establish green baseline**

Run: `mix precommit`
Expected: all tests pass.

- [ ] **Step 2: Switch Phoenix json_library config**

In `config/config.exs`, replace line 63:

```elixir
# Before:
config :phoenix, :json_library, Jason

# After:
config :phoenix, :json_library, JSON
```

- [ ] **Step 3: Replace `Jason.encode!` with `JSON.encode!` in RateLimiter**

In `lib/drink_water_web/plugs/rate_limiter.ex`, line 57:

```elixir
# Before:
|> send_resp(429, Jason.encode!(ProblemDetail.build(conn, :rate_limit_exceeded)))

# After:
|> send_resp(429, JSON.encode!(ProblemDetail.build(conn, :rate_limit_exceeded)))
```

- [ ] **Step 4: Replace `Jason.OrderedObject` with plain map in alarm_settings_json**

In `lib/drink_water_web/controllers/alarm_settings_json.ex`, replace the `data/1` function:

```elixir
# Before:
defp data(%AlarmSettings{} = alarm_settings) do
  Jason.OrderedObject.new(
    id: alarm_settings.id,
    goal: alarm_settings.goal,
    interval_minutes: alarm_settings.interval_minutes,
    daily_start_time: alarm_settings.daily_start_time,
    daily_end_time: alarm_settings.daily_end_time
  )
end

# After:
defp data(%AlarmSettings{} = alarm_settings) do
  %{
    id: alarm_settings.id,
    goal: alarm_settings.goal,
    interval_minutes: alarm_settings.interval_minutes,
    daily_start_time: alarm_settings.daily_start_time,
    daily_end_time: alarm_settings.daily_end_time
  }
end
```

Note: JSON key ordering is lost, but JSON spec (RFC 8259) says object member order is not significant.

- [ ] **Step 5: Replace `Jason.decode!` with `JSON.decode!` in user_controller_test**

In `test/drink_water_web/controllers/user_controller_test.exs`, lines 207 and 226:

```elixir
# Before:
response = Jason.decode!(body)

# After:
response = JSON.decode!(body)
```

- [ ] **Step 6: Replace `Jason.DecodeError` with `JSON.DecodeError` in error_json_test**

In `test/drink_water_web/controllers/error_json_test.exs`, line 25:

```elixir
# Before:
reason = %Plug.Parsers.ParseError{exception: %Jason.DecodeError{data: ""}}

# After:
reason = %Plug.Parsers.ParseError{exception: %JSON.DecodeError{data: ""}}
```

- [ ] **Step 7: Run full precommit to verify nothing breaks**

Run: `mix precommit`
Expected: all tests pass. Phoenix now uses `JSON` for all serialization.

- [ ] **Step 8: Commit**

```bash
git add config/config.exs lib/drink_water_web/plugs/rate_limiter.ex lib/drink_water_web/controllers/alarm_settings_json.ex test/drink_water_web/controllers/user_controller_test.exs test/drink_water_web/controllers/error_json_test.exs
git commit -m "chore: switch Phoenix json_library from Jason to JSON (Elixir 1.18+ native)"
```

---

### Task 1: ProblemDetail struct — new/1, new/2, and reason phrases

**Files:**
- Create: `lib/problem_detail.ex`
- Create: `test/problem_detail_test.exs`

- [ ] **Step 1: Write failing tests for `new/1` and `new/2`**

In `test/problem_detail_test.exs`:

```elixir
defmodule ProblemDetailTest do
  use ExUnit.Case, async: true

  describe "new/1" do
    test "creates a problem detail with status and auto-resolved title" do
      pd = ProblemDetail.new(404)

      assert %ProblemDetail{} = pd
      assert pd.status == 404
      assert pd.title == "Not Found"
      assert pd.type == nil
      assert pd.detail == nil
      assert pd.instance == nil
      assert pd.properties == %{}
    end

    test "resolves title for common status codes" do
      assert ProblemDetail.new(400).title == "Bad Request"
      assert ProblemDetail.new(409).title == "Conflict"
      assert ProblemDetail.new(422).title == "Unprocessable Content"
      assert ProblemDetail.new(429).title == "Too Many Requests"
      assert ProblemDetail.new(500).title == "Internal Server Error"
    end

    test "defaults title to nil for unknown status codes" do
      pd = ProblemDetail.new(499)

      assert pd.status == 499
      assert pd.title == nil
    end
  end

  describe "new/2" do
    test "accepts optional fields via keyword list" do
      pd = ProblemDetail.new(409,
        type: "https://example.com/conflict",
        detail: "Already exists",
        instance: "https://example.com/api/users/1"
      )

      assert pd.status == 409
      assert pd.type == "https://example.com/conflict"
      assert pd.detail == "Already exists"
      assert pd.instance == "https://example.com/api/users/1"
      assert pd.title == "Conflict"
    end

    test "title in opts overrides auto-resolved value" do
      pd = ProblemDetail.new(500, title: "Erro Interno")

      assert pd.title == "Erro Interno"
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/problem_detail_test.exs`
Expected: compilation error — `ProblemDetail` module not found.

- [ ] **Step 3: Implement `ProblemDetail` struct with `new/1`, `new/2`, and reason phrases**

In `lib/problem_detail.ex`:

```elixir
defmodule ProblemDetail do
  @moduledoc """
  RFC 9457 Problem Detail struct for HTTP API error responses.

  A generic, zero-dependency value type representing an RFC 9457 problem detail.
  Designed to be reusable across Elixir projects.

  See: https://www.rfc-editor.org/rfc/rfc9457
  """

  @type t :: %__MODULE__{
          status: pos_integer(),
          type: String.t() | nil,
          title: String.t() | nil,
          detail: String.t() | nil,
          instance: String.t() | nil,
          properties: map()
        }

  @enforce_keys [:status]
  defstruct [
    :type,
    :title,
    :status,
    :detail,
    :instance,
    properties: %{}
  ]

  @reason_phrases %{
    100 => "Continue",
    101 => "Switching Protocols",
    102 => "Processing",
    103 => "Early Hints",
    200 => "OK",
    201 => "Created",
    202 => "Accepted",
    203 => "Non-Authoritative Information",
    204 => "No Content",
    205 => "Reset Content",
    206 => "Partial Content",
    207 => "Multi-Status",
    208 => "Already Reported",
    226 => "IM Used",
    300 => "Multiple Choices",
    301 => "Moved Permanently",
    302 => "Found",
    303 => "See Other",
    304 => "Not Modified",
    305 => "Use Proxy",
    307 => "Temporary Redirect",
    308 => "Permanent Redirect",
    400 => "Bad Request",
    401 => "Unauthorized",
    402 => "Payment Required",
    403 => "Forbidden",
    404 => "Not Found",
    405 => "Method Not Allowed",
    406 => "Not Acceptable",
    407 => "Proxy Authentication Required",
    408 => "Request Timeout",
    409 => "Conflict",
    410 => "Gone",
    411 => "Length Required",
    412 => "Precondition Failed",
    413 => "Content Too Large",
    414 => "URI Too Long",
    415 => "Unsupported Media Type",
    416 => "Range Not Satisfiable",
    417 => "Expectation Failed",
    418 => "I'm a Teapot",
    421 => "Misdirected Request",
    422 => "Unprocessable Content",
    423 => "Locked",
    424 => "Failed Dependency",
    425 => "Too Early",
    426 => "Upgrade Required",
    428 => "Precondition Required",
    429 => "Too Many Requests",
    431 => "Request Header Fields Too Large",
    451 => "Unavailable For Legal Reasons",
    500 => "Internal Server Error",
    501 => "Not Implemented",
    502 => "Bad Gateway",
    503 => "Service Unavailable",
    504 => "Gateway Timeout",
    505 => "HTTP Version Not Supported",
    506 => "Variant Also Negotiates",
    507 => "Insufficient Storage",
    508 => "Loop Detected",
    510 => "Not Extended",
    511 => "Network Authentication Required"
  }

  @spec new(pos_integer()) :: t()
  def new(status) when is_integer(status) and status > 0 do
    %__MODULE__{status: status, title: Map.get(@reason_phrases, status)}
  end

  @spec new(pos_integer(), keyword()) :: t()
  def new(status, opts) when is_integer(status) and status > 0 and is_list(opts) do
    title = Keyword.get(opts, :title, Map.get(@reason_phrases, status))

    %__MODULE__{
      status: status,
      type: Keyword.get(opts, :type),
      title: title,
      detail: Keyword.get(opts, :detail),
      instance: Keyword.get(opts, :instance)
    }
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/problem_detail_test.exs`
Expected: all 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/problem_detail.ex test/problem_detail_test.exs
git commit -m "feat: add ProblemDetail struct with new/1, new/2, and RFC 9110 reason phrases"
```

---

### Task 2: ProblemDetail pipe API — put_* functions

**Files:**
- Modify: `lib/problem_detail.ex`
- Modify: `test/problem_detail_test.exs`

- [ ] **Step 1: Write failing tests for put_* functions**

Append to `test/problem_detail_test.exs`:

```elixir
describe "put_type/2" do
  test "sets the type URI" do
    pd = ProblemDetail.new(404) |> ProblemDetail.put_type("https://example.com/not-found")

    assert pd.type == "https://example.com/not-found"
  end
end

describe "put_title/2" do
  test "overrides the auto-resolved title" do
    pd = ProblemDetail.new(500) |> ProblemDetail.put_title("Erro Interno")

    assert pd.title == "Erro Interno"
  end
end

describe "put_detail/2" do
  test "sets the detail message" do
    pd = ProblemDetail.new(404) |> ProblemDetail.put_detail("User 999 not found")

    assert pd.detail == "User 999 not found"
  end
end

describe "put_instance/2" do
  test "sets the instance URI" do
    pd = ProblemDetail.new(404) |> ProblemDetail.put_instance("https://example.com/api/users/999")

    assert pd.instance == "https://example.com/api/users/999"
  end
end

describe "put_extension/3" do
  test "adds an extension to properties with string key" do
    pd = ProblemDetail.new(422) |> ProblemDetail.put_extension("errors", %{name: ["required"]})

    assert pd.properties == %{"errors" => %{name: ["required"]}}
  end

  test "converts atom keys to strings" do
    pd = ProblemDetail.new(500) |> ProblemDetail.put_extension(:trace_id, "abc-123")

    assert pd.properties == %{"trace_id" => "abc-123"}
  end

  test "multiple extensions accumulate" do
    pd =
      ProblemDetail.new(400)
      |> ProblemDetail.put_extension("trace_id", "abc")
      |> ProblemDetail.put_extension("request_id", "xyz")

    assert pd.properties == %{"trace_id" => "abc", "request_id" => "xyz"}
  end
end

describe "pipe composition" do
  test "builds a complete problem detail via pipes" do
    pd =
      ProblemDetail.new(422)
      |> ProblemDetail.put_type("https://example.com/validation-error")
      |> ProblemDetail.put_detail("Invalid input")
      |> ProblemDetail.put_instance("https://example.com/api/users")
      |> ProblemDetail.put_extension("errors", %{name: ["required"]})

    assert pd.status == 422
    assert pd.title == "Unprocessable Content"
    assert pd.type == "https://example.com/validation-error"
    assert pd.detail == "Invalid input"
    assert pd.instance == "https://example.com/api/users"
    assert pd.properties == %{"errors" => %{name: ["required"]}}
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/problem_detail_test.exs`
Expected: `UndefinedFunctionError` for `put_type/2`, etc.

- [ ] **Step 3: Implement put_* functions**

Add to `lib/problem_detail.ex` after `new/2`:

```elixir
@spec put_type(t(), String.t()) :: t()
def put_type(%__MODULE__{} = pd, type) when is_binary(type) do
  %{pd | type: type}
end

@spec put_title(t(), String.t()) :: t()
def put_title(%__MODULE__{} = pd, title) when is_binary(title) do
  %{pd | title: title}
end

@spec put_detail(t(), String.t()) :: t()
def put_detail(%__MODULE__{} = pd, detail) when is_binary(detail) do
  %{pd | detail: detail}
end

@spec put_instance(t(), String.t()) :: t()
def put_instance(%__MODULE__{} = pd, instance) when is_binary(instance) do
  %{pd | instance: instance}
end

@spec put_extension(t(), String.Chars.t(), term()) :: t()
def put_extension(%__MODULE__{} = pd, key, value) do
  %{pd | properties: Map.put(pd.properties, to_string(key), value)}
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/problem_detail_test.exs`
Expected: all 13 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/problem_detail.ex test/problem_detail_test.exs
git commit -m "feat: add ProblemDetail put_* pipe API"
```

---

### Task 3: ProblemDetail JSON serialization via JSON.Encoder

**Files:**
- Modify: `lib/problem_detail.ex`
- Modify: `test/problem_detail_test.exs`

- [ ] **Step 1: Write failing tests for JSON encoding**

Append to `test/problem_detail_test.exs`:

```elixir
describe "JSON serialization" do
  test "encodes with defaults — about:blank type and auto-resolved title" do
    json = ProblemDetail.new(500) |> JSON.encode!() |> JSON.decode!()

    assert json == %{
      "type" => "about:blank",
      "title" => "Internal Server Error",
      "status" => 500
    }
  end

  test "omits nil detail and instance from output" do
    json = ProblemDetail.new(404) |> JSON.encode!() |> JSON.decode!()

    refute Map.has_key?(json, "detail")
    refute Map.has_key?(json, "instance")
  end

  test "encodes all fields when present" do
    json =
      ProblemDetail.new(404)
      |> ProblemDetail.put_type("https://example.com/not-found")
      |> ProblemDetail.put_detail("User not found")
      |> ProblemDetail.put_instance("https://example.com/api/users/999")
      |> JSON.encode!()
      |> JSON.decode!()

    assert json == %{
      "type" => "https://example.com/not-found",
      "title" => "Not Found",
      "status" => 404,
      "detail" => "User not found",
      "instance" => "https://example.com/api/users/999"
    }
  end

  test "flattens properties as top-level JSON fields" do
    json =
      ProblemDetail.new(404)
      |> ProblemDetail.put_detail("Not found")
      |> ProblemDetail.put_extension("trace_id", "abc-123")
      |> JSON.encode!()
      |> JSON.decode!()

    assert json["trace_id"] == "abc-123"
    refute Map.has_key?(json, "properties")
  end

  test "standard fields win over extension name collisions" do
    json =
      ProblemDetail.new(400)
      |> ProblemDetail.put_detail("Real detail")
      |> ProblemDetail.put_extension("detail", "Fake detail")
      |> ProblemDetail.put_extension("custom", "kept")
      |> JSON.encode!()
      |> JSON.decode!()

    assert json["detail"] == "Real detail"
    assert json["custom"] == "kept"
  end

  test "encodes nested extension values" do
    json =
      ProblemDetail.new(422)
      |> ProblemDetail.put_extension("errors", %{email: ["can't be blank"]})
      |> JSON.encode!()
      |> JSON.decode!()

    assert json["errors"] == %{"email" => ["can't be blank"]}
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/problem_detail_test.exs`
Expected: `Protocol.UndefinedError` — `JSON.Encoder` not implemented for `ProblemDetail`.

- [ ] **Step 3: Implement `JSON.Encoder` protocol**

Add at the end of `lib/problem_detail.ex` (inside the module, before the final `end`). Uses a `@doc false` public function because `defimpl` cannot access private functions:

```elixir
@standard_field_names ~w(type title status detail instance)

@doc false
def __to_json_map__(%__MODULE__{} = pd) do
  standard =
    %{"type" => pd.type || "about:blank", "status" => pd.status}
    |> put_non_nil("title", pd.title || Map.get(@reason_phrases, pd.status))
    |> put_non_nil("detail", pd.detail)
    |> put_non_nil("instance", pd.instance)

  filtered_props = Map.drop(pd.properties, @standard_field_names)

  Map.merge(filtered_props, standard)
end

defp put_non_nil(map, _key, nil), do: map
defp put_non_nil(map, key, value), do: Map.put(map, key, value)

defimpl JSON.Encoder do
  def encode(pd, encoder) do
    pd
    |> ProblemDetail.__to_json_map__()
    |> encoder.(encoder)
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/problem_detail_test.exs`
Expected: all 19 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/problem_detail.ex test/problem_detail_test.exs
git commit -m "feat: add ProblemDetail JSON.Encoder with properties flattening"
```

---

### Task 4: Create ErrorCatalog (Layer 2)

**Files:**
- Create: `lib/drink_water_web/error_catalog.ex`
- Create: `test/drink_water_web/error_catalog_test.exs`

- [ ] **Step 1: Write failing tests for ErrorCatalog**

In `test/drink_water_web/error_catalog_test.exs`:

```elixir
defmodule DrinkWaterWeb.ErrorCatalogTest do
  use DrinkWaterWeb.ConnCase, async: true

  alias DrinkWaterWeb.ErrorCatalog

  @test_base_uri "http://www.example.com"

  defp conn_with_path(path) do
    build_conn(:get, path)
  end

  describe "build/1 (generic 500)" do
    test "returns internal server error as ProblemDetail struct" do
      result = ErrorCatalog.build(conn_with_path("/api/users"))

      assert %ProblemDetail{} = result
      assert result.type == "https://www.drinkwater.com.br/internal-server-error"
      assert result.title == "Internal Server Error"
      assert result.status == 500
      assert result.detail == "An unexpected error occurred. Please try again later or contact support."
      assert result.instance == @test_base_uri <> "/api/users"
    end
  end

  describe "build/2 (single-key catalog)" do
    test "bad_request returns 400 with specific type and detail" do
      result = ErrorCatalog.build(conn_with_path("/api/users"), :bad_request)

      assert result.type == "https://www.drinkwater.com.br/invalid-argument"
      assert result.title == "Bad Request"
      assert result.status == 400
      assert result.detail == "An invalid argument was provided."
      assert result.instance == @test_base_uri <> "/api/users"
    end

    test "parsing_error returns 400" do
      result = ErrorCatalog.build(conn_with_path("/api/users"), :parsing_error)

      assert result.type == "https://www.drinkwater.com.br/parsing-error"
      assert result.status == 400
    end

    test "rate_limit_exceeded returns 429" do
      result = ErrorCatalog.build(conn_with_path("/api/users/1/water_intakes"), :rate_limit_exceeded)

      assert result.type == "https://www.drinkwater.com.br/rate-limit-exceeded"
      assert result.status == 429
      assert result.detail == "Too many requests. Please wait before trying again."
      assert result.instance == @test_base_uri <> "/api/users/1/water_intakes"
    end
  end

  describe "build/3 (composite-key catalog)" do
    test "not_found user returns 404" do
      result = ErrorCatalog.build(conn_with_path("/api/users/999"), :not_found, :user)

      assert result.type == "https://www.drinkwater.com.br/user-not-found"
      assert result.title == "Not Found"
      assert result.status == 404
      assert result.detail == "The requested user account was not found."
      assert result.instance == @test_base_uri <> "/api/users/999"
    end

    test "not_found alarm_settings returns 404" do
      result = ErrorCatalog.build(conn_with_path("/api/users/1/alarm_settings"), :not_found, :alarm_settings)

      assert result.type == "https://www.drinkwater.com.br/alarm-settings-not-found"
      assert result.status == 404
    end

    test "not_found water_intake returns 404" do
      result = ErrorCatalog.build(conn_with_path("/api/users/1/water_intakes/99"), :not_found, :water_intake)

      assert result.type == "https://www.drinkwater.com.br/waterintake-not-found"
      assert result.status == 404
    end

    test "conflict user returns 409" do
      result = ErrorCatalog.build(conn_with_path("/api/users"), :conflict, :user)

      assert result.type == "https://www.drinkwater.com.br/user-already-exists"
      assert result.status == 409
    end

    test "conflict alarm_settings returns 409" do
      result = ErrorCatalog.build(conn_with_path("/api/users/1/alarm_settings"), :conflict, :alarm_settings)

      assert result.type == "https://www.drinkwater.com.br/alarm-settings-already-exists"
      assert result.status == 409
    end

    test "conflict water_intake returns 409" do
      result = ErrorCatalog.build(conn_with_path("/api/users/1/water_intakes"), :conflict, :water_intake)

      assert result.type == "https://www.drinkwater.com.br/waterintake-duplicate-datetime"
      assert result.status == 409
    end
  end

  describe "from_changeset/2" do
    test "returns 422 with validation errors in properties" do
      changeset =
        %DrinkWater.UserManagement.User{}
        |> Ecto.Changeset.change()
        |> Ecto.Changeset.add_error(:email, "can't be blank")
        |> Ecto.Changeset.add_error(:first_name, "is too short")

      result = ErrorCatalog.from_changeset(conn_with_path("/api/users"), changeset)

      assert %ProblemDetail{} = result
      assert result.type == "https://www.drinkwater.com.br/validation-error"
      assert result.title == "Unprocessable Content"
      assert result.status == 422
      assert result.detail == "One or more fields are invalid. Please correct them and try again."
      assert result.instance == @test_base_uri <> "/api/users"
      assert result.properties["errors"][:email] == ["can't be blank"]
      assert result.properties["errors"][:first_name] == ["is too short"]
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

      result = ErrorCatalog.from_changeset(conn_with_path("/api/users"), changeset)
      assert result.properties["errors"][:first_name] == ["should be at least 2 character(s)"]
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/drink_water_web/error_catalog_test.exs`
Expected: compilation error — `DrinkWaterWeb.ErrorCatalog` not found.

- [ ] **Step 3: Implement ErrorCatalog**

Create `lib/drink_water_web/error_catalog.ex`:

```elixir
defmodule DrinkWaterWeb.ErrorCatalog do
  @moduledoc """
  Project-specific error catalog that builds ProblemDetail structs
  from categorized error keys, with Gettext i18n and Plug.Conn integration.
  """

  use Gettext, backend: DrinkWaterWeb.Gettext

  # Extraction hints — these calls let `mix gettext.extract` discover the strings.
  dgettext_noop("errors", "The requested user account was not found.")
  dgettext_noop("errors", "The requested alarm settings were not found.")
  dgettext_noop("errors", "The requested water intake record was not found.")
  dgettext_noop("errors", "A user with this email address already exists.")
  dgettext_noop("errors", "Alarm settings already exist for this user.")
  dgettext_noop("errors", "A water intake record already exists for the specified date and time.")
  dgettext_noop("errors", "An invalid argument was provided.")

  dgettext_noop(
    "errors",
    "Unable to process the request. Please check that your data is properly formatted."
  )

  dgettext_noop("errors", "Too many requests. Please wait before trying again.")
  dgettext_noop("errors", "One or more fields are invalid. Please correct them and try again.")

  dgettext_noop(
    "errors",
    "An unexpected error occurred. Please try again later or contact support."
  )

  @type_base_url "https://www.drinkwater.com.br"

  @catalog %{
    {:not_found, :user} =>
      {404, "user-not-found", "The requested user account was not found."},
    {:not_found, :alarm_settings} =>
      {404, "alarm-settings-not-found", "The requested alarm settings were not found."},
    {:not_found, :water_intake} =>
      {404, "waterintake-not-found", "The requested water intake record was not found."},
    {:conflict, :user} =>
      {409, "user-already-exists", "A user with this email address already exists."},
    {:conflict, :alarm_settings} =>
      {409, "alarm-settings-already-exists", "Alarm settings already exist for this user."},
    {:conflict, :water_intake} =>
      {409, "waterintake-duplicate-datetime",
       "A water intake record already exists for the specified date and time."},
    :bad_request =>
      {400, "invalid-argument", "An invalid argument was provided."},
    :parsing_error =>
      {400, "parsing-error",
       "Unable to process the request. Please check that your data is properly formatted."},
    :rate_limit_exceeded =>
      {429, "rate-limit-exceeded", "Too many requests. Please wait before trying again."},
    :validation_error =>
      {422, "validation-error",
       "One or more fields are invalid. Please correct them and try again."},
    :internal_server_error =>
      {500, "internal-server-error",
       "An unexpected error occurred. Please try again later or contact support."}
  }

  @spec build(Plug.Conn.t()) :: ProblemDetail.t()
  def build(%Plug.Conn{} = conn) do
    build_from_entry(conn, @catalog[:internal_server_error])
  end

  @spec build(Plug.Conn.t(), atom()) :: ProblemDetail.t()
  def build(%Plug.Conn{} = conn, key) when is_atom(key) do
    build_from_entry(conn, Map.fetch!(@catalog, key))
  end

  @spec build(Plug.Conn.t(), atom(), atom()) :: ProblemDetail.t()
  def build(%Plug.Conn{} = conn, category, resource)
      when is_atom(category) and is_atom(resource) do
    build_from_entry(conn, Map.fetch!(@catalog, {category, resource}))
  end

  @spec from_changeset(Plug.Conn.t(), Ecto.Changeset.t()) :: ProblemDetail.t()
  def from_changeset(%Plug.Conn{} = conn, %Ecto.Changeset{} = changeset) do
    build(conn, :validation_error)
    |> ProblemDetail.put_extension("errors", translate_errors(changeset))
  end

  defp build_from_entry(conn, {status, slug, message}) do
    ProblemDetail.new(status)
    |> ProblemDetail.put_type("#{@type_base_url}/#{slug}")
    |> ProblemDetail.put_detail(Gettext.dgettext(DrinkWaterWeb.Gettext, "errors", message))
    |> ProblemDetail.put_instance(request_uri(conn))
  end

  defp request_uri(conn) do
    base = "#{conn.scheme}://#{conn.host}:#{conn.port}#{conn.request_path}"
    uri = URI.new!(base)

    case conn.query_string do
      "" -> URI.to_string(uri)
      qs -> uri |> URI.append_query(qs) |> URI.to_string()
    end
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

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/drink_water_web/error_catalog_test.exs`
Expected: all 13 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/drink_water_web/error_catalog.ex test/drink_water_web/error_catalog_test.exs
git commit -m "feat: add ErrorCatalog project-specific layer using ProblemDetail struct"
```

---

### Task 5: Update FallbackController to use ErrorCatalog

**Files:**
- Modify: `lib/drink_water_web/controllers/fallback_controller.ex`

- [ ] **Step 1: Run existing tests to establish green baseline**

Run: `mix test test/drink_water_web/controllers/`
Expected: all pass (current state).

- [ ] **Step 2: Update FallbackController**

In `lib/drink_water_web/controllers/fallback_controller.ex`, change the alias:

Replace:
```elixir
alias DrinkWaterWeb.ProblemDetail
```

With:
```elixir
alias DrinkWaterWeb.ErrorCatalog
```

Replace all 4 occurrences of `ProblemDetail.` with `ErrorCatalog.`:
- `ProblemDetail.build(conn, :not_found, resource)` → `ErrorCatalog.build(conn, :not_found, resource)`
- `ProblemDetail.build(conn, :conflict, resource)` → `ErrorCatalog.build(conn, :conflict, resource)`
- `ProblemDetail.build(conn, :bad_request)` → `ErrorCatalog.build(conn, :bad_request)`
- `ProblemDetail.from_changeset(conn, changeset)` → `ErrorCatalog.from_changeset(conn, changeset)`

- [ ] **Step 3: Run controller tests to verify they still pass**

Run: `mix test test/drink_water_web/controllers/`
Expected: all pass. The JSON output is identical because `JSON.Encoder` produces the same fields.

- [ ] **Step 4: Commit**

```bash
git add lib/drink_water_web/controllers/fallback_controller.ex
git commit -m "refactor: FallbackController uses ErrorCatalog instead of ProblemDetail"
```

---

### Task 6: Update ErrorJSON to use ErrorCatalog and ProblemDetail struct

**Files:**
- Modify: `lib/drink_water_web/controllers/error_json.ex`
- Modify: `test/drink_water_web/controllers/error_json_test.exs`

- [ ] **Step 1: Update ErrorJSON**

In `lib/drink_water_web/controllers/error_json.ex`, replace the full contents with:

```elixir
defmodule DrinkWaterWeb.ErrorJSON do
  @moduledoc """
  Renders API error responses as RFC 9457 Problem Details.

  Serves two paths:
  - `error/1` — called by FallbackController for business errors
  - `render/2` — called by Endpoint render_errors for unhandled exceptions
  """

  alias DrinkWaterWeb.ErrorCatalog

  @doc "Called by FallbackController — returns the pre-built ProblemDetail struct."
  def error(%{problem: %ProblemDetail{} = problem}), do: problem

  @doc "Called by Endpoint render_errors — dispatches by exception type."
  def render(_template, %{conn: conn, reason: %Plug.Parsers.ParseError{}}) do
    ErrorCatalog.build(conn, :parsing_error)
  end

  def render(_template, %{conn: conn, reason: %Phoenix.ActionClauseError{}}) do
    ErrorCatalog.build(conn, :bad_request)
  end

  def render(_template, %{conn: conn}) do
    ErrorCatalog.build(conn)
  end
end
```

- [ ] **Step 2: Update error/1 test to use ProblemDetail struct**

In `test/drink_water_web/controllers/error_json_test.exs`, update the `error/1` test:

Replace:
```elixir
test "returns the problem map as-is" do
  problem = %{type: "test", title: "Test", status: 400, detail: "test", instance: "/test"}
  assert ErrorJSON.error(%{problem: problem}) == problem
end
```

With:
```elixir
test "returns the ProblemDetail struct as-is" do
  problem = ProblemDetail.new(400, type: "test", detail: "test")
  assert ErrorJSON.error(%{problem: problem}) == problem
end
```

- [ ] **Step 3: Run ErrorJSON tests**

Run: `mix test test/drink_water_web/controllers/error_json_test.exs`
Expected: all 4 tests pass. The `render/2` tests already assert field-by-field so they work with both maps and structs.

- [ ] **Step 4: Commit**

```bash
git add lib/drink_water_web/controllers/error_json.ex test/drink_water_web/controllers/error_json_test.exs
git commit -m "refactor: ErrorJSON uses ErrorCatalog and accepts ProblemDetail struct"
```

---

### Task 7: Update RateLimiter plug

**Files:**
- Modify: `lib/drink_water_web/plugs/rate_limiter.ex`

- [ ] **Step 1: Update RateLimiter**

In `lib/drink_water_web/plugs/rate_limiter.ex`:

Replace:
```elixir
alias DrinkWaterWeb.ProblemDetail
```

With:
```elixir
alias DrinkWaterWeb.ErrorCatalog
```

Replace line 57 (already changed to `JSON.encode!` by Task 0):
```elixir
|> send_resp(429, JSON.encode!(ProblemDetail.build(conn, :rate_limit_exceeded)))
```

With:
```elixir
|> send_resp(429, JSON.encode!(ErrorCatalog.build(conn, :rate_limit_exceeded)))
```

- [ ] **Step 2: Run rate limiter tests**

Run: `mix test test/drink_water_web/plugs/rate_limiter_test.exs`
Expected: all pass.

- [ ] **Step 3: Commit**

```bash
git add lib/drink_water_web/plugs/rate_limiter.ex
git commit -m "refactor: RateLimiter uses ErrorCatalog and JSON.encode!"
```

---

### Task 8: Delete old ProblemDetail and its test

**Files:**
- Delete: `lib/drink_water_web/problem_detail.ex`
- Delete: `test/drink_water_web/controllers/problem_detail_test.exs`

- [ ] **Step 1: Verify no remaining references to DrinkWaterWeb.ProblemDetail**

Run: `grep -r "DrinkWaterWeb.ProblemDetail" lib/ test/ --include="*.ex" --include="*.exs"`
Expected: no matches (all references should have been updated in Tasks 5-7).

- [ ] **Step 2: Delete the old files**

```bash
git rm lib/drink_water_web/problem_detail.ex
git rm test/drink_water_web/controllers/problem_detail_test.exs
```

- [ ] **Step 3: Run full precommit**

Run: `mix precommit`
Expected: compilation passes with no warnings, all tests pass.

- [ ] **Step 4: Commit**

```bash
git commit -m "refactor: remove DrinkWaterWeb.ProblemDetail — replaced by ProblemDetail + ErrorCatalog"
```

---

### Task 9: Final verification

- [ ] **Step 1: Run full precommit one final time**

Run: `mix precommit`
Expected: `compile --warnings-as-errors` passes, `deps.unlock --unused` passes, `format` passes, all tests pass.

- [ ] **Step 2: Verify no Dialyzer warnings (if available)**

Check IDE diagnostics on `lib/problem_detail.ex` and `lib/drink_water_web/error_catalog.ex` — should show no warnings about opaque types or undefined functions.

- [ ] **Step 3: Review git log for clean commit history**

Run: `git log --oneline -8`
Expected: 7 focused commits following the task progression.
