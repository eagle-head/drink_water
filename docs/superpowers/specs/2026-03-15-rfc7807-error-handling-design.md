# RFC 7807 Error Handling Redesign

**Date:** 2026-03-15
**Status:** Draft
**Reference:** Java project at `/home/eduardo/Documents/drink-water-api`

## Problem

The current error handling returns minimal, generic Problem Details responses (`type: "about:blank"`, no `detail`, no `instance`). API consumers (mobile apps, external clients) cannot distinguish error types programmatically or get useful human-readable messages. The Java implementation provides full RFC 7807 compliance that we need to replicate.

## Approach

**Enriched error tuples + FallbackController.** Idiomatic Elixir/Phoenix: contexts return enriched error tuples, the FallbackController pattern-matches and delegates to a centralized ProblemDetail module that builds full RFC 7807 responses. Gettext provides i18n-ready message resolution.

## Error Catalog

Every API error maps to a specific entry:

| Error tuple                              | Status | Type slug                  | Detail message (Gettext, domain `errors`)                                             |
|------------------------------------------|--------|----------------------------|---------------------------------------------------------------------------------------|
| `{:error, :not_found, :user}`            | 404    | `user-not-found`           | `"The requested user account was not found."`                                         |
| `{:error, :not_found, :alarm_settings}`  | 404    | `alarm-settings-not-found` | `"The requested alarm settings were not found."`                                      |
| `{:error, :not_found, :water_intake}`    | 404    | `waterintake-not-found`    | `"The requested water intake record was not found."`                                  |
| `{:error, :conflict, :user}`             | 409    | `user-already-exists`      | `"A user with this email address already exists."`                                    |
| `{:error, :conflict, :alarm_settings}`   | 409    | `alarm-settings-already-exists` | `"Alarm settings already exist for this user."`                                  |
| `{:error, :conflict, :water_intake}`     | 409    | `waterintake-duplicate-datetime` | `"A water intake record already exists for the specified date and time."`        |
| `{:error, :bad_request}`                 | 400    | `invalid-argument`         | `"An invalid argument was provided."`                                                 |
| `{:error, %Ecto.Changeset{}}`            | 422    | `validation-error`         | `"One or more fields are invalid. Please correct them and try again."`                |
| `Plug.Parsers.ParseError` (malformed JSON) | 400  | `parsing-error`            | `"Unable to process the request. Please check that your data is properly formatted."` |
| `Phoenix.ActionClauseError` (missing params key) | 400 | `invalid-argument`    | `"An invalid argument was provided."`                                                 |
| Rate limit denied                        | 429    | `rate-limit-exceeded`      | `"Too many requests. Please wait before trying again."`                               |
| Unexpected error (catch-all)             | 500    | `internal-server-error`    | `"An unexpected error occurred. Please try again later or contact support."`          |

**Type URI pattern:** `https://www.drinkwater.com.br/{slug}` (same as Java project).

**Instance:** `conn.request_path` (e.g., `/api/users/1`) — matches the Java project which uses the request path. This tells the consumer which resource had the problem.

## Response Format

Error responses from the FallbackController use `Content-Type: application/problem+json; charset=utf-8`. Endpoint-level crash responses (500) use `application/json` because Phoenix's `render_errors` pipeline does not allow setting custom content types from the view — this is an acceptable trade-off since the body is still a valid Problem Details JSON.

### 404 — Not Found

```json
{
  "type": "https://www.drinkwater.com.br/user-not-found",
  "title": "Not Found",
  "status": 404,
  "detail": "The requested user account was not found.",
  "instance": "/api/users/999"
}
```

### 422 — Validation Error

```json
{
  "type": "https://www.drinkwater.com.br/validation-error",
  "title": "Unprocessable Content",
  "status": 422,
  "detail": "One or more fields are invalid. Please correct them and try again.",
  "instance": "/api/users",
  "errors": {
    "email": ["can't be blank"],
    "first_name": ["should be at least 2 character(s)"]
  }
```

**Note on `errors` format:** The Java project uses an array of `[{"field": "email", "message": "..."}]`. This Phoenix implementation uses a map of `{"email": ["..."]}` which is the idiomatic Ecto format from `Ecto.Changeset.traverse_errors/2`. This is a deliberate divergence — mobile clients consuming the new Phoenix API will use the map format.

### 409 — Conflict (duplicate resource)

```json
{
  "type": "https://www.drinkwater.com.br/user-already-exists",
  "title": "Conflict",
  "status": 409,
  "detail": "A user with this email address already exists.",
  "instance": "/api/users"
}
```

### 400 — Bad Request

```json
{
  "type": "https://www.drinkwater.com.br/invalid-argument",
  "title": "Bad Request",
  "status": 400,
  "detail": "An invalid argument was provided.",
  "instance": "/api/users/1/water_intakes"
}
```

### 400 — Malformed JSON (Plug.Parsers.ParseError)

```json
{
  "type": "https://www.drinkwater.com.br/parsing-error",
  "title": "Bad Request",
  "status": 400,
  "detail": "Unable to process the request. Please check that your data is properly formatted.",
  "instance": "/api/users"
}
```

### 429 — Rate Limit Exceeded

```json
{
  "type": "https://www.drinkwater.com.br/rate-limit-exceeded",
  "title": "Too Many Requests",
  "status": 429,
  "detail": "Too many requests. Please wait before trying again.",
  "instance": "/api/users/1/water_intakes"
}
```

With `Retry-After` header in seconds.

### 500 — Internal Server Error

```json
{
  "type": "https://www.drinkwater.com.br/internal-server-error",
  "title": "Internal Server Error",
  "status": 500,
  "detail": "An unexpected error occurred. Please try again later or contact support.",
  "instance": "/api/users"
}
```

No internal details (stack traces, exception messages) are ever exposed.

## Module Architecture

### ProblemDetail (`lib/drink_water_web/problem_detail.ex`)

Centralized RFC 7807 builder. Contains the error catalog as a private map. Resolves `detail` messages via Gettext (domain `errors`).

Uses `use Gettext, backend: DrinkWaterWeb.Gettext` to access Gettext functions. Does NOT read `conn.status` — the status comes from the error catalog lookup.

**Public API — explicit function heads:**

```elixir
# Arity 1 — generic 500 (for Endpoint render_errors)
build(conn) :: map()

# Arity 2 — single-key catalog lookup (e.g., :bad_request, :rate_limit_exceeded)
build(conn, error_key) :: map()

# Arity 3 — composite-key catalog lookup (e.g., :not_found + :user)
build(conn, category, resource) :: map()

# Changeset errors — 422 with field-level errors
from_changeset(conn, changeset) :: map()
```

**Internal structure:**

```elixir
@type_base_url "https://www.drinkwater.com.br"

@error_catalog %{
  # Composite keys
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
  # Single keys
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
```

Messages are resolved at call time via `dgettext("errors", message)`.

### FallbackController (`lib/drink_water_web/controllers/fallback_controller.ex`)

Thin dispatcher — pattern matches error tuples and delegates to ProblemDetail:

```elixir
def call(conn, {:error, :not_found, resource}) do
  conn
  |> put_resp_content_type("application/problem+json")
  |> put_status(:not_found)
  |> put_view(json: DrinkWaterWeb.ErrorJSON)
  |> render(:error, problem: ProblemDetail.build(conn, :not_found, resource))
end

def call(conn, {:error, :conflict, resource}) do
  conn
  |> put_resp_content_type("application/problem+json")
  |> put_status(:conflict)
  |> put_view(json: DrinkWaterWeb.ErrorJSON)
  |> render(:error, problem: ProblemDetail.build(conn, :conflict, resource))
end

def call(conn, {:error, :bad_request}) do
  conn
  |> put_resp_content_type("application/problem+json")
  |> put_status(:bad_request)
  |> put_view(json: DrinkWaterWeb.ErrorJSON)
  |> render(:error, problem: ProblemDetail.build(conn, :bad_request))
end

def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
  conn
  |> put_resp_content_type("application/problem+json")
  |> put_status(:unprocessable_entity)
  |> put_view(json: DrinkWaterWeb.ErrorJSON)
  |> render(:error, problem: ProblemDetail.from_changeset(conn, changeset))
end
```

A `put_problem_content_type/1` private helper can extract the repeated `put_resp_content_type("application/problem+json")` call.

### ErrorJSON (`lib/drink_water_web/controllers/error_json.ex`)

Unified error view for all API errors:

```elixir
# Called by FallbackController (business errors)
def error(%{problem: problem}), do: problem

# Called by render_errors in Endpoint (unexpected errors / crashes)
def render(_template, %{conn: conn}), do: ProblemDetail.build(conn)
```

The `error/1` function is invoked when FallbackController calls `render(conn, :error, problem: ...)`. The `render/2` function is invoked by Phoenix's `render_errors` when an unhandled exception reaches the Endpoint.

### ChangesetJSON — removed

Absorbed into ErrorJSON. `ProblemDetail.from_changeset/2` handles everything.

### RateLimiter plug (`lib/drink_water_web/plugs/rate_limiter.ex`)

Updated to use `ProblemDetail.build(conn, :rate_limit_exceeded)` instead of manual map construction.

### Endpoint-level exception handling

Some exceptions are raised before reaching any controller and are caught by the Endpoint's `render_errors`, which routes to `ErrorJSON.render/2`. The `render_errors` assigns include `reason` (the exception struct) and `conn` (with status already set via `Plug.Exception` protocol).

| Exception | `Plug.Exception` status | Catalog entry |
|---|---|---|
| `Plug.Parsers.ParseError` (malformed JSON) | 400 | `:parsing_error` |
| `Phoenix.ActionClauseError` (missing params key) | 400 | `:bad_request` |
| Any other exception | 500 | `:internal_server_error` |

**ErrorJSON.render/2** dispatches based on the `reason` in assigns:

```elixir
def render(_template, %{conn: conn, reason: %Plug.Parsers.ParseError{}}) do
  ProblemDetail.build(conn, :parsing_error)
end

def render(_template, %{conn: conn, reason: %Phoenix.ActionClauseError{}}) do
  ProblemDetail.build(conn, :bad_request)
end

def render(_template, %{conn: conn}) do
  ProblemDetail.build(conn)
end
```

This gives specific Problem Details for known exception types and falls back to generic 500 for anything unexpected.

## Context Changes

### Enriched not_found tuples

| Context function                                   | Before                 | After                                   |
|----------------------------------------------------|------------------------|-----------------------------------------|
| `UserManagement.get_user/1`                        | `{:error, :not_found}` | `{:error, :not_found, :user}`           |
| `UserManagement.get_alarm_settings_by_user/1`      | `{:error, :not_found}` | `{:error, :not_found, :alarm_settings}` |
| `HydrationTracking.get_water_intake/2`             | `{:error, :not_found}` | `{:error, :not_found, :water_intake}`   |

### Conflict detection from unique constraints

Context functions that call `Repo.insert` or `Repo.update` need to inspect the changeset error for unique constraint violations and convert them to `{:error, :conflict, resource}` tuples:

| Context function                                   | Unique constraint                | Conflict tuple                            |
|----------------------------------------------------|----------------------------------|-------------------------------------------|
| `UserManagement.create_user/1`                     | `:email`                         | `{:error, :conflict, :user}`              |
| `UserManagement.create_alarm_settings/2`           | `:user_id`                       | `{:error, :conflict, :alarm_settings}`    |
| `HydrationTracking.create_water_intake/2`          | `[:user_id, :date_time_utc]`     | `{:error, :conflict, :water_intake}`      |
| `HydrationTracking.update_water_intake/2`          | `[:user_id, :date_time_utc]`     | `{:error, :conflict, :water_intake}`      |

**Implementation:** After `Repo.insert/update`, check if the returned changeset has a unique constraint error on the relevant field. If so, return `{:error, :conflict, resource}` instead of `{:error, changeset}`. Other changeset errors (validation) continue as `{:error, changeset}`.

Controllers are NOT modified — they use `with` + `action_fallback` and the enriched tuples flow through automatically.

**Note on non-integer IDs:** When `get_user("abc")` is called, it returns `{:error, :not_found, :user}`. The consumer sees a "user not found" 404 — this is acceptable because from the consumer's perspective, there is no user with that ID.

## Gettext Integration

**Backend:** `DrinkWaterWeb.Gettext` (already exists).

**Domain:** `errors` (existing domain, already used by Ecto changeset messages).

**Import in ProblemDetail:**

```elixir
use Gettext, backend: DrinkWaterWeb.Gettext
```

New messages added to `priv/gettext/errors.pot` and `priv/gettext/en/LC_MESSAGES/errors.po`:

- `"The requested user account was not found."`
- `"The requested alarm settings were not found."`
- `"The requested water intake record was not found."`
- `"A user with this email address already exists."`
- `"Alarm settings already exist for this user."`
- `"A water intake record already exists for the specified date and time."`
- `"An invalid argument was provided."`
- `"One or more fields are invalid. Please correct them and try again."`
- `"Unable to process the request. Please check that your data is properly formatted."`
- `"Too many requests. Please wait before trying again."`
- `"An unexpected error occurred. Please try again later or contact support."`

Run `mix gettext.extract --merge` after adding messages.

## Configuration

- `config/dev.exs`: `debug_errors: false` (already done) — ensures API errors always go through ErrorJSON, not the Plug.Debugger.

## Testing Strategy

**ProblemDetailTest** — tests each catalog entry: given a `conn` + error args, validates all 5 RFC 7807 fields (`type`, `title`, `status`, `detail`, `instance`). Tests `build/1`, `build/2`, `build/3`, and `from_changeset/2`.

**ErrorJSONTest** — tests both paths: `error(%{problem: problem})` passthrough and `render(template, %{conn: conn})` for 500s.

**Controller tests (existing)** — updated assertions to validate all 5 RFC 7807 fields on error responses.

**RateLimiterTest (existing)** — updated to validate `type`, `detail`, `instance`.

## Files Modified

| File | Action |
|------|--------|
| `lib/drink_water_web/problem_detail.ex` | Rewrite — catalog + Gettext |
| `lib/drink_water_web/controllers/fallback_controller.ex` | Rewrite — enriched pattern match |
| `lib/drink_water_web/controllers/error_json.ex` | Rewrite — unified error view |
| `lib/drink_water_web/controllers/changeset_json.ex` | Remove — absorbed by ErrorJSON |
| `lib/drink_water_web/plugs/rate_limiter.ex` | Update — use ProblemDetail |
| `lib/drink_water/user_management.ex` | Update — enriched not_found tuples + conflict detection |
| `lib/drink_water/hydration_tracking.ex` | Update — enriched not_found tuples + conflict detection |
| `priv/gettext/errors.pot` | Update — add catalog messages |
| `priv/gettext/en/LC_MESSAGES/errors.po` | Update — merge new messages |
| All error-related test files | Update — validate 5 RFC 7807 fields |

## Files NOT Modified

- Controllers (`UserController`, `AlarmSettingsController`, `WaterIntakeController`) — unchanged, `with` + `action_fallback` works as-is
- `ErrorHTML` — unchanged, browser errors unaffected
- `InputSanitizer` — unchanged, doesn't return errors
- Schemas — unchanged, validation rules stay the same

## Backlog

- Structured logging in FallbackController (info for 4xx, warning for 429)
- Portuguese translations (`priv/gettext/pt_BR/LC_MESSAGES/errors.po`)

## Philosophy

- **Let it crash** — Exceptions are not caught or suppressed. Unexpected errors crash the process, the supervisor restarts it, and the Endpoint's `render_errors` returns a generic 500 via ErrorJSON.
- **Errors are data** — Business errors flow as tuples, not exceptions. The FallbackController translates them to HTTP responses.
- **No internal details exposed** — Stack traces, exception messages, module names never appear in API responses. They stay in server logs.
