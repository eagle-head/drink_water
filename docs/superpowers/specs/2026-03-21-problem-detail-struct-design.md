# ProblemDetail Struct — RFC 9457 Reusable Module

**Date:** 2026-03-21
**Status:** Approved
**Goal:** Extract a generic, zero-dependency `ProblemDetail` struct that implements RFC 9457, ready to be reused across Elixir projects and eventually proposed as a Phoenix/Elixir ecosystem library.

---

## Context

The current `DrinkWaterWeb.ProblemDetail` module mixes three concerns:
1. The RFC 9457 data structure (5 fields + extensions)
2. A project-specific error catalog (slugs, messages, Gettext)
3. HTTP integration (Plug.Conn for `instance`, content-type)

This makes it impossible to reuse across projects. Spring Framework solves this with a clean separation: `ProblemDetail` (pure value object) vs `ErrorResponse`/`@ControllerAdvice` (framework integration). We want the same decoupling, done the Elixir way.

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Philosophy | Elixir/Phoenix idioms first | Structs, protocols, pipes, pattern matching — not an OOP port |
| JSON library | `JSON` (Elixir 1.18+ native) | Encourages the standard solution the platform recommends |
| Location | `lib/problem_detail.ex` inside drink_water | Zero coupling to `DrinkWater*`, extractable to hex later |
| Ecto support | Outside the generic module | Changeset → properties conversion is project responsibility |
| Plug support | Outside the generic module | `instance` from Conn is project responsibility |
| Gettext support | Outside the generic module | i18n is project responsibility |

## Architecture

### Layer 1: Generic Module (reusable, zero deps)

```
lib/problem_detail.ex          # Struct + API + JSON.Encoder + reason phrases
test/problem_detail_test.exs   # Tests as usage examples
```

### Layer 2: Project Integration (DrinkWaterWeb)

```
lib/drink_water_web/error_catalog.ex    # Catalog + Gettext + Conn helpers
lib/drink_water_web/controllers/fallback_controller.ex  # Uses ErrorCatalog
lib/drink_water_web/controllers/error_json.ex           # Returns struct directly
```

### What disappears

- `lib/drink_water_web/problem_detail.ex` — replaced by Layer 1 + Layer 2

---

## Layer 1: `ProblemDetail` Struct

### Struct Definition

```elixir
defmodule ProblemDetail do
  @moduledoc """
  RFC 9457 Problem Detail struct for HTTP API error responses.

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
end
```

**Fields:**
- `status` (integer, required) — HTTP status code. Immutable after creation.
- `type` (string | nil) — URI identifying the problem type. Defaults to `"about:blank"` in serialization.
- `title` (string | nil) — Short human-readable summary. Auto-resolved from status, overridable. If the status code has no known reason phrase, defaults to `nil`.
- `detail` (string | nil) — Human-readable explanation specific to this occurrence.
- `instance` (string | nil) — URI identifying this specific occurrence.
- `properties` (map, default `%{}`) — Extension members (RFC 9457 §3.2). Flattened to top-level in JSON.

### Public API

```elixir
# Factory
ProblemDetail.new(status)                    # => %ProblemDetail{status: 404, title: "Not Found"}
ProblemDetail.new(status, opts)              # opts: [:type, :title, :detail, :instance]
                                             # :properties intentionally excluded — use put_extension/3

# Setters (pipe-friendly, return %ProblemDetail{})
ProblemDetail.put_type(pd, type)
ProblemDetail.put_title(pd, title)
ProblemDetail.put_detail(pd, detail)
ProblemDetail.put_instance(pd, instance)
ProblemDetail.put_extension(pd, key, value)  # adds to properties map
```

**Design rules:**
- `new/1` and `new/2` auto-resolve `title` from status via internal reason phrase lookup.
- No `put_status/2` — status is immutable. The RFC says status MUST match the HTTP response code; allowing mutation invites inconsistency.
- `put_title/2` overrides the auto-resolved default (for i18n or custom titles).
- `put_extension/3` uses the RFC 9457 term "extension member" (§3.2). Adds to the `properties` map. **Keys are always converted to strings** via `to_string/1` — this ensures consistent collision detection with standard field names and deterministic JSON output.
- All `put_*` functions receive and return `%ProblemDetail{}` — standard Elixir pipe pattern (like `Plug.Conn.put_resp_header/3`).

### Reason Phrase Lookup

An internal map from HTTP status code to reason phrase, embedded in the module. No dependency on `Plug.Conn.Status`. Covers all standard HTTP status codes (RFC 9110).

```elixir
# Internal, not part of public API
@reason_phrases %{
  400 => "Bad Request",
  401 => "Unauthorized",
  403 => "Forbidden",
  404 => "Not Found",
  # ... all standard codes
  500 => "Internal Server Error",
  # ...
}
```

### JSON Serialization

Implements the `JSON.Encoder` protocol (Elixir 1.18+).

**Serialization rules:**
1. `type` — if `nil`, emit `"about:blank"` (RFC 9457 §3.1.1 default)
2. `title` — if `nil`, emit reason phrase for the status
3. `status` — always emitted as integer
4. `detail` — if `nil`, omitted from output
5. `instance` — if `nil`, omitted from output
6. `properties` — each key-value pair emitted as a top-level JSON field (flattened, like Spring's Jackson mixin)
7. **Collision handling** — if a `properties` key conflicts with a standard field name (`type`, `title`, `status`, `detail`, `instance`), the standard field wins and the extension is silently ignored. **Implementation:** build the standard fields map first, filter colliding keys from `properties`, then merge: `Map.merge(filtered_properties, standard_fields)`

**Example:**

```elixir
ProblemDetail.new(422)
|> ProblemDetail.put_type("https://example.com/validation-error")
|> ProblemDetail.put_detail("One or more fields are invalid.")
|> ProblemDetail.put_extension("errors", %{email: ["can't be blank"]})
|> JSON.encode!()
```

Output:
```json
{
  "type": "https://example.com/validation-error",
  "title": "Unprocessable Content",
  "status": 422,
  "detail": "One or more fields are invalid.",
  "errors": {"email": ["can't be blank"]}
}
```

---

## Layer 2: Project Integration (`DrinkWaterWeb`)

### ErrorCatalog

Replaces the current `DrinkWaterWeb.ProblemDetail`. Knows about:
- The project's error catalog (slugs, messages)
- Gettext for i18n
- `Plug.Conn` for building `instance` URI

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
  dgettext_noop("errors", "Unable to process the request. Please check that your data is properly formatted.")
  dgettext_noop("errors", "Too many requests. Please wait before trying again.")
  dgettext_noop("errors", "One or more fields are invalid. Please correct them and try again.")
  dgettext_noop("errors", "An unexpected error occurred. Please try again later or contact support.")

  @type_base_url "https://www.drinkwater.com.br"

  @catalog %{
    {:not_found, :user}            => {404, "user-not-found", "The requested user account was not found."},
    {:not_found, :alarm_settings}  => {404, "alarm-settings-not-found", "The requested alarm settings were not found."},
    {:not_found, :water_intake}    => {404, "waterintake-not-found", "The requested water intake record was not found."},
    {:conflict, :user}             => {409, "user-already-exists", "A user with this email address already exists."},
    {:conflict, :alarm_settings}   => {409, "alarm-settings-already-exists", "Alarm settings already exist for this user."},
    {:conflict, :water_intake}     => {409, "waterintake-duplicate-datetime", "A water intake record already exists for the specified date and time."},
    :bad_request                   => {400, "invalid-argument", "An invalid argument was provided."},
    :parsing_error                 => {400, "parsing-error", "Unable to process the request. Please check that your data is properly formatted."},
    :rate_limit_exceeded           => {429, "rate-limit-exceeded", "Too many requests. Please wait before trying again."},
    :validation_error              => {422, "validation-error", "One or more fields are invalid. Please correct them and try again."},
    :internal_server_error         => {500, "internal-server-error", "An unexpected error occurred. Please try again later or contact support."}
  }

  @spec build(Plug.Conn.t()) :: ProblemDetail.t()
  def build(conn), do: build_from_entry(conn, @catalog[:internal_server_error])

  @spec build(Plug.Conn.t(), atom()) :: ProblemDetail.t()
  def build(conn, key) when is_atom(key), do: build_from_entry(conn, Map.fetch!(@catalog, key))

  @spec build(Plug.Conn.t(), atom(), atom()) :: ProblemDetail.t()
  def build(conn, category, resource),
    do: build_from_entry(conn, Map.fetch!(@catalog, {category, resource}))

  @spec from_changeset(Plug.Conn.t(), Ecto.Changeset.t()) :: ProblemDetail.t()
  def from_changeset(conn, changeset) do
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

### FallbackController Changes

Minimal — swap `ProblemDetail` alias for `ErrorCatalog`:

```elixir
# Before:
alias DrinkWaterWeb.ProblemDetail
ProblemDetail.build(conn, :not_found, resource)

# After:
alias DrinkWaterWeb.ErrorCatalog
ErrorCatalog.build(conn, :not_found, resource)
```

### ErrorJSON Changes

All clauses updated — both `error/1` (FallbackController path) and `render/2` (Endpoint render_errors path):

```elixir
# error/1 — returns struct directly, JSON.Encoder handles serialization
def error(%{problem: %ProblemDetail{} = problem}), do: problem

# render/2 — also updated to use ErrorCatalog instead of ProblemDetail
def render(_template, %{conn: conn, reason: %Plug.Parsers.ParseError{}}) do
  ErrorCatalog.build(conn, :parsing_error)
end

def render(_template, %{conn: conn, reason: %Phoenix.ActionClauseError{}}) do
  ErrorCatalog.build(conn, :bad_request)
end

def render(_template, %{conn: conn}) do
  ErrorCatalog.build(conn)
end
```

---

## Testing Strategy

### Layer 1 Tests (`test/problem_detail_test.exs`)

Tests read like usage examples. No database, no Conn, no Gettext.

```elixir
defmodule ProblemDetailTest do
  use ExUnit.Case, async: true

  describe "new/1" do
    test "creates a problem detail with status and auto-resolved title" do
      pd = ProblemDetail.new(404)

      assert pd.status == 404
      assert pd.title == "Not Found"
      assert pd.type == nil
      assert pd.detail == nil
      assert pd.instance == nil
      assert pd.properties == %{}
    end
  end

  describe "new/2" do
    test "accepts optional fields via keyword list" do
      pd = ProblemDetail.new(409,
        type: "https://example.com/conflict",
        detail: "Already exists"
      )

      assert pd.status == 409
      assert pd.type == "https://example.com/conflict"
      assert pd.detail == "Already exists"
      assert pd.title == "Conflict"
    end
  end

  describe "pipe API" do
    test "builds a complete problem detail via pipes" do
      pd =
        ProblemDetail.new(422)
        |> ProblemDetail.put_type("https://example.com/validation-error")
        |> ProblemDetail.put_detail("Invalid input")
        |> ProblemDetail.put_instance("https://example.com/api/users")
        |> ProblemDetail.put_extension("errors", %{name: ["required"]})

      assert pd.status == 422
      assert pd.type == "https://example.com/validation-error"
      assert pd.detail == "Invalid input"
      assert pd.instance == "https://example.com/api/users"
      assert pd.properties == %{"errors" => %{name: ["required"]}}
    end

    test "put_title/2 overrides the auto-resolved default" do
      pd = ProblemDetail.new(500) |> ProblemDetail.put_title("Erro Interno")

      assert pd.title == "Erro Interno"
    end
  end

  describe "JSON serialization" do
    test "encodes with flattened properties and defaults" do
      json =
        ProblemDetail.new(404)
        |> ProblemDetail.put_detail("Not found")
        |> ProblemDetail.put_extension("trace_id", "abc-123")
        |> JSON.encode!()
        |> JSON.decode!()

      assert json == %{
        "type" => "about:blank",
        "title" => "Not Found",
        "status" => 404,
        "detail" => "Not found",
        "trace_id" => "abc-123"
      }
    end

    test "omits nil detail and instance from output" do
      json = ProblemDetail.new(500) |> JSON.encode!() |> JSON.decode!()

      assert json == %{
        "type" => "about:blank",
        "title" => "Internal Server Error",
        "status" => 500
      }
      refute Map.has_key?(json, "detail")
      refute Map.has_key?(json, "instance")
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
  end
end
```

### Layer 2 Tests (`test/drink_water_web/error_catalog_test.exs`)

Adapted from existing `problem_detail_test.exs`. Uses `Plug.Conn`, Gettext, and the project catalog.

### Existing Controller Tests

Minimal changes — swap expected module references. All assertions remain the same since the JSON output is identical.

---

## Migration Path

1. Create `lib/problem_detail.ex` with struct, API, and `JSON.Encoder`
2. Create `test/problem_detail_test.exs`
3. Create `lib/drink_water_web/error_catalog.ex` (move catalog + Gettext + dgettext_noop hints + Conn logic)
4. Update `FallbackController` — swap `ProblemDetail` alias for `ErrorCatalog`
5. Update `ErrorJSON` — both `error/1` (pattern match on `%ProblemDetail{}`) and all `render/2` clauses (use `ErrorCatalog` instead of `ProblemDetail`)
6. Update `RateLimiter` plug — use `ErrorCatalog` and switch `Jason.encode!` to `JSON.encode!`
7. Rewrite `test/drink_water_web/controllers/problem_detail_test.exs` → `test/drink_water_web/error_catalog_test.exs` — **note:** this is a full rewrite, not just a rename, because the return type changes from plain map to `%ProblemDetail{}` struct. Assertions like `result == %{type: ..., instance: ...}` must become struct field assertions (`result.type`, `result.status`, etc.) or `%ProblemDetail{}` pattern matches. `result.errors` becomes `result.properties["errors"]`.
8. Update controller tests — JSON response assertions stay the same (JSON output is identical). Only swap module names in any direct references.
9. Delete `lib/drink_water_web/problem_detail.ex`
10. Run `mix precommit` — all tests must pass

## Future: Extraction to Hex Package

When mature, extracting to a hex package requires:
1. Move `lib/problem_detail.ex` + `test/problem_detail_test.exs` to a new mix project
2. Add `{:problem_detail, "~> 0.1"}` to drink_water's deps
3. No code changes needed — the public API is already decoupled
