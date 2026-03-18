# Step 9: Observability — Design Spec

## Context

The drink_water Phoenix project has completed Phases 1-4 (CRUD, pagination, error handling, rate limiting, LiveView dashboard with 98.5% test coverage). Step 9 adds observability: telemetry enhancement, structured logging, custom domain events, Prometheus metrics, distributed tracing, and a health check endpoint.

**Scope decision:** Only substeps that run locally without external services. Sentry (9g), Loki (9h), and Grafana dashboards (9j) are deferred to backlog.

**Active substeps:** 9a, 9b, 9c, 9d, 9e, 9f, 9i

## Decisions

| Decision               | Choice                                              | Rationale                                                                                                                   |
| ---------------------- | --------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| Approach               | Bottom-Up Incremental (7 commits)                   | Consistent with project history (8a-8j pattern). Each commit passes `mix precommit`.                                        |
| PromEx in test         | Disabled                                            | Tests use `:telemetry.attach/4` directly. No need for PromEx server in test.                                                |
| OpenTelemetry exporter | `:none` in dev/test                                 | Code ready, zero overhead. Enable when collector available.                                                                 |
| Log persistence        | OTP native file handler + LoggerJSON formatter      | Two simultaneous handlers: console (human) + file (JSON). Zero extra deps beyond LoggerJSON.                                |
| Custom events          | `:telemetry.span/3` wrapping all context operations | Measures both count AND duration. Covers all 11 existing operations across both contexts (5 hydration + 6 user management). |
| Backlog items          | Sentry (9g), Loki (9h), Grafana (9j)                | Require external services/accounts. Will be addressed when infra is ready.                                                  |

## Execution Order

```
9a (Telemetry enhance) → 9b (LiveDashboard) → 9i (Health check)
→ 9c (JSON logging) → 9d (Custom events) → 9e (PromEx)
→ 9f (OpenTelemetry)
```

## Architecture Overview

```
                    ┌─────────────────────────────────────────────────┐
                    │              Phoenix Endpoint                    │
                    │  Plug.RequestId → Plug.Telemetry → Router       │
                    └──────────┬───────────────┬──────────────────────┘
                               │               │
                    ┌──────────▼───────┐  ┌────▼──────────────┐
                    │  REST Controllers │  │  LiveView         │
                    │  (API pipeline)   │  │  (Browser pipe)   │
                    └──────────┬───────┘  └────┬──────────────┘
                               │               │
                    ┌──────────▼───────────────▼──────────────────┐
                    │              Contexts                        │
                    │  UserManagement    HydrationTracking         │
                    │  ┌─────────────────────────────────┐        │
                    │  │  :telemetry.span/3 wrapping      │        │
                    │  │  (measures duration + count)      │        │
                    │  └─────────────────────────────────┘        │
                    │  PubSub broadcasts (existing)               │
                    └──────────┬──────────────────────────────────┘
                               │
                    ┌──────────▼──────────────────────────────────┐
                    │              Ecto / PostgreSQL               │
                    └─────────────────────────────────────────────┘

     Consumers:
     ┌──────────────┐  ┌────────────┐  ┌──────────────┐  ┌──────────┐
     │ LiveDashboard │  │  PromEx    │  │ OpenTelemetry│  │  Logger  │
     │ (dev UI)      │  │ (port 4021)│  │ (exporter)   │  │ (file +  │
     │               │  │ Prometheus │  │              │  │  console)│
     └──────────────┘  └────────────┘  └──────────────┘  └──────────┘
```

---

## Step 9a: Telemetry Foundation Enhancement

**Goal:** Add LiveView metrics, remove from test coverage ignore list.

**Files modified:**

- `lib/drink_water_web/telemetry.ex` — Add LiveView metrics to `metrics/0`
- `mix.exs` — Remove `DrinkWaterWeb.Telemetry` from `ignore_modules`

**New metrics in `metrics/0`:**

```elixir
summary("phoenix.live_view.mount.stop.duration", unit: {:native, :millisecond}, tags: [:view])
summary("phoenix.live_view.handle_event.stop.duration", unit: {:native, :millisecond}, tags: [:event])
summary("phoenix.live_view.handle_params.stop.duration", unit: {:native, :millisecond}, tags: [:view])
```

**Tests:** `test/drink_water_web/telemetry_test.exs`

- `metrics/0` returns list of `%Telemetry.Metrics.Summary{}` / `%Telemetry.Metrics.Sum{}` structs
- List includes metrics from each group (phoenix, ecto, vm, live_view)
- `init/1` returns expected supervisor child spec shape (test spec structure, not start actual supervisor to avoid telemetry_poller conflicts)

---

## Step 9b: Phoenix LiveDashboard Extra Panels

**Goal:** Enable OS Data panel via `:os_mon`.

**Files modified:**

- `mix.exs` — Add `:os_mon` to `extra_applications: [:logger, :runtime_tools, :os_mon]`

**No tests.** Dev tool — verified manually via `/dev/dashboard`.

---

## Step 9i: Health Check Endpoint

**Goal:** `GET /api/health` — DB connectivity + BEAM stats. No rate limiting.

**Files created:**

- `lib/drink_water_web/controllers/health_controller.ex`
- `test/drink_water_web/controllers/health_controller_test.exs`

**Files modified:**

- `lib/drink_water_web/router.ex` — Route before rate-limited scopes
- `config/prod.exs` — Uncomment `paths: ["/api/health"]` in `force_ssl` exclude

**Response format:**

```json
{
  "status": "healthy",
  "checks": {
    "database": "ok",
    "beam": {
      "uptime_seconds": 1234,
      "memory_mb": 128,
      "process_count": 312,
      "schedulers": 8
    }
  }
}
```

HTTP 200 when healthy, 503 when degraded (DB unreachable).

**503 response format (same structure, different values):**

```json
{
  "status": "degraded",
  "checks": {
    "database": "error",
    "beam": {
      "uptime_seconds": 1234,
      "memory_mb": 128,
      "process_count": 312,
      "schedulers": 8
    }
  }
}
```

**DB check:** `Ecto.Adapters.SQL.query(DrinkWater.Repo, "SELECT 1", [])`

**Tests:**

- 200 with `"status" => "healthy"`, correct JSON structure with all expected fields
- BEAM stats contain expected keys (uptime_seconds, memory_mb, process_count, schedulers)

---

## Step 9c: Structured JSON Logging

**Goal:** Two OTP logger handlers — console (human-readable) + file (JSON structured).

**New dependency:** `{:logger_json, "~> 7.0"}`

**Files created:**

- `lib/drink_water_web/plugs/log_metadata.ex` — Sets `user_id` in Logger metadata from route params
- `test/drink_water_web/plugs/log_metadata_test.exs`

**Files modified:**

- `mix.exs` — Add `logger_json` dep
- `lib/drink_water/application.ex` — Add `Logger.add_handlers(:drink_water)` at top of `start/2`
- `config/config.exs` — Add `:user_id` to metadata: `metadata: [:request_id, :user_id]`
- `config/dev.exs` — Add OTP file handler writing JSON to `logs/dev.log`
- `config/prod.exs` — Console handler with JSON formatter (stdout for external capture)
- `config/test.exs` — No file handler
- `lib/drink_water_web/router.ex` — Add `LogMetadata` plug to `:api` pipeline after `InputSanitizer`
- `.gitignore` — Add `logs/`

**LogMetadata plug:**

```elixir
defmodule DrinkWaterWeb.Plugs.LogMetadata do
  @behaviour Plug
  require Logger

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    user_id = conn.params["user_id"] || conn.params["id"]
    if user_id, do: Logger.metadata(user_id: user_id)
    conn
  end
end
```

**Dev file handler config — uses app-scoped `:logger` key + `Logger.add_handlers/1`:**

The existing `config :logger, :default_formatter, format: "[$level] $message\n"` in `dev.exs` is kept as-is for console output. The JSON file handler is registered under the app's own namespace:

```elixir
# config/dev.exs — add JSON file handler (console handler stays unchanged via :default_formatter)
config :drink_water, :logger, [
  {:handler, :file_json, :logger_std_h, %{
    config: %{file: ~c"logs/dev.log", max_no_bytes: 10_485_760, max_no_files: 3},
    formatter: LoggerJSON.Formatters.Basic.new(metadata: [:request_id, :user_id])
  }}
]
```

**Critical:** `Logger.add_handlers(:drink_water)` must be called in `Application.start/2` to activate the file handler. Without this call, the handler config is ignored silently.

**Files modified (updated):** Also modifies `lib/drink_water/application.ex` — add `Logger.add_handlers(:drink_water)` at top of `start/2`.

**Tests:** LogMetadata plug sets metadata when `user_id` present, no crash when absent.

---

## Step 9d: Custom Telemetry Events

**Goal:** Instrument all context operations with `:telemetry.span/3` for count + duration measurement.

**Files created:**

- `lib/drink_water/telemetry_events.ex` — Central event module
- `test/drink_water/telemetry_events_test.exs`

**Files modified:**

- `lib/drink_water/hydration_tracking.ex` — Wrap 5 operations: `create_water_intake`, `update_water_intake`, `delete_water_intake`, `delete_water_intake_by_id`, `list_water_intakes`
- `lib/drink_water/user_management.ex` — Wrap 6 operations: `create_user`, `update_user`, `delete_user_by_id`, `create_alarm_settings`, `update_alarm_settings`, `delete_alarm_settings`

**Note on `delete_user_by_id/1`:** Returns bare `:ok` (not a tuple). The span wrapper must normalize: `{:ok, %{}}` to satisfy `:telemetry.span/3` which expects `{result, extra_measurements}`.

**Note on `intake_deleted` event:** Both `delete_water_intake/1` and `delete_water_intake_by_id/2` emit `[:drink_water, :hydration, :intake_deleted]` — same event, different call signatures. The `TelemetryEvents` span function handles both by accepting `user_id` as metadata.

- `lib/drink_water_web/telemetry.ex` — Add domain metrics to `metrics/0`

**Event naming convention:** `[:drink_water, <context>, <action>]`

**Full event list:**
| Event | Metadata |
|-------|----------|
| `[:drink_water, :hydration, :intake_created]` | `%{user_id: id}`, measurements: `%{volume: int}` + auto duration |
| `[:drink_water, :hydration, :intake_updated]` | `%{user_id: id}` |
| `[:drink_water, :hydration, :intake_deleted]` | `%{user_id: id}` |
| `[:drink_water, :hydration, :intake_search]` | `%{user_id: id}` |
| `[:drink_water, :users, :user_created]` | `%{}` |
| `[:drink_water, :users, :user_updated]` | `%{user_id: id}` |
| `[:drink_water, :users, :user_deleted]` | `%{user_id: id}` |
| `[:drink_water, :users, :alarm_settings_created]` | `%{user_id: id}` |
| `[:drink_water, :users, :alarm_settings_updated]` | `%{user_id: id}` |
| `[:drink_water, :users, :alarm_settings_deleted]` | `%{user_id: id}` |

**`:telemetry.span/3` pattern:**

```elixir
def span_intake_created(metadata, fun) do
  :telemetry.span([:drink_water, :hydration, :intake_created], metadata, fun)
end
```

This automatically emits `:start`, `:stop` (with `duration`), and `:exception` events.

**Usage in context:**

```elixir
def create_water_intake(user_id, attrs) do
  TelemetryEvents.span_intake_created(%{user_id: user_id}, fn ->
    result = %WaterIntake{user_id: user_id}
      |> WaterIntake.changeset(attrs)
      |> Repo.insert()
      |> maybe_conflict(:water_intake)

    case result do
      {:ok, intake} ->
        broadcast_event(intake.user_id, :intake_created)
        {result, %{volume: intake.volume}}
      _ ->
        {result, %{}}
    end
  end)
end
```

The span function expects `fn -> {result, extra_measurements} end`.

**Tests:** Attach handler with `:telemetry.attach/4`, call each `span_*` with dummy function, `assert_receive` for `:stop` event with `duration` in measurements and correct metadata. Detach in `on_exit`.

---

## Step 9e: Prometheus Metrics Export (PromEx)

**Goal:** Export all metrics in Prometheus format on port 4021.

**New dependency:** `{:prom_ex, "~> 1.11"}`

**Files created:**

- `lib/drink_water/prom_ex.ex`
- `test/drink_water/prom_ex_test.exs`

**Files modified:**

- `mix.exs` — Add dep, add `DrinkWater.PromEx` to `ignore_modules`
- `lib/drink_water/application.ex` — Add `DrinkWater.PromEx` to supervision tree before Endpoint
- `config/config.exs` — PromEx base config
- `config/test.exs` — `config :drink_water, DrinkWater.PromEx, disabled: true`

**PromEx module:**

```elixir
defmodule DrinkWater.PromEx do
  use PromEx, otp_app: :drink_water

  @impl true
  def plugins do
    [
      PromEx.Plugins.Application,
      PromEx.Plugins.Beam,
      {PromEx.Plugins.Phoenix, router: DrinkWaterWeb.Router, endpoint: DrinkWaterWeb.Endpoint},
      {PromEx.Plugins.Ecto, repos: [DrinkWater.Repo]}
    ]
  end

  @impl true
  def dashboard_assigns do
    [datasource_id: "prometheus", default_selected_interval: "30s"]
  end

  @impl true
  def dashboards do
    [{:prom_ex, "application.json"}, {:prom_ex, "beam.json"},
     {:prom_ex, "phoenix.json"}, {:prom_ex, "ecto.json"}]
  end
end
```

**Config:**

```elixir
# config/config.exs — base config (dev only serves metrics on port 4021)
config :drink_water, DrinkWater.PromEx,
  disabled: false,
  manual_metrics_start_delay: :no_delay,
  drop_metrics_groups: [],
  grafana: :disabled,
  metrics_server: [port: 4021, path: "/metrics"]

# config/prod.exs — disable metrics_server in prod (use PromEx Plug behind auth instead)
config :drink_water, DrinkWater.PromEx,
  metrics_server: :disabled
```

**Security note:** The `metrics_server` exposes an unauthenticated HTTP endpoint. In prod, disable it and expose metrics via a PromEx Plug behind authentication instead. For dev, port 4021 on localhost is fine.

**Supervision tree order after 9e:**

1. DrinkWaterWeb.Telemetry
2. DrinkWater.Repo
3. DNSCluster
4. Phoenix.PubSub
5. DrinkWater.RateLimit
6. **DrinkWater.PromEx** (new)
7. DrinkWaterWeb.Endpoint

**Tests:** `plugins/0`, `dashboards/0`, `dashboard_assigns/0` return expected structures.

---

## Step 9f: Request Tracing (OpenTelemetry)

**Goal:** Distributed tracing for Phoenix → Ecto. Exporter `:none` in dev/test.

**New dependencies (versions confirmed via `mix hex.info` 2026-03-18):**

```elixir
{:opentelemetry, "~> 1.7"}
{:opentelemetry_api, "~> 1.5"}
{:opentelemetry_exporter, "~> 1.10"}
{:opentelemetry_phoenix, "~> 2.0"}
{:opentelemetry_ecto, "~> 1.2"}
{:opentelemetry_bandit, "~> 0.3.0"}
```

**Files created:**

- `lib/drink_water/otel_setup.ex`
- `test/drink_water/otel_setup_test.exs`

**Files modified:**

- `mix.exs` — Add deps
- `lib/drink_water/application.ex` — Call `DrinkWater.OtelSetup.setup()` at top of `start/2`
- `config/dev.exs` — `config :opentelemetry, traces_exporter: :none`
- `config/test.exs` — `config :opentelemetry, traces_exporter: :none`
- `config/runtime.exs` — OTLP endpoint from env var in prod block

**OtelSetup module:**

```elixir
defmodule DrinkWater.OtelSetup do
  def setup do
    OpentelemetryBandit.setup()
    OpentelemetryPhoenix.setup(adapter: :bandit)
    OpentelemetryEcto.setup([:drink_water, :repo])
  end
end
```

**Application.start/2:**

```elixir
def start(_type, _args) do
  DrinkWater.OtelSetup.setup()
  children = [...]
```

**Runtime config (prod block):**

```elixir
config :opentelemetry, :resource, service: [name: "drink_water"]
config :opentelemetry,
  span_processor: :batch,
  traces_exporter: {:otlp,
    endpoint: System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4318")}
```

**Tests:** `setup/0` doesn't raise, idempotent (calling twice is safe).

---

## Backlog (deferred)

| Step | What                  | Why deferred                     |
| ---- | --------------------- | -------------------------------- |
| 9g   | Sentry error tracking | Requires external account + DSN  |
| 9h   | Loki log aggregation  | Docker infra, depends on 9c      |
| 9j   | Grafana dashboards    | Docker infra, depends on 9e + 9h |

---

## Verification Plan

After all 7 substeps:

1. `mix precommit` — all tests pass, zero warnings
2. `mix phx.server` — app boots cleanly
3. `curl localhost:4000/api/health` — returns 200 healthy JSON
4. `curl localhost:4021/metrics` — returns Prometheus text format
5. Visit `localhost:4000/dev/dashboard` — Metrics, OS Data, Ecto Stats tabs populated
6. Create a water intake via API — verify in `logs/dev.log` that JSON log line appears with request_id and user_id
7. Check `logs/dev.log` contains structured JSON entries with duration data

## Files Summary

**New files (11):**

- `lib/drink_water_web/controllers/health_controller.ex`
- `lib/drink_water_web/plugs/log_metadata.ex`
- `lib/drink_water/telemetry_events.ex`
- `lib/drink_water/prom_ex.ex`
- `lib/drink_water/otel_setup.ex`
- `test/drink_water_web/telemetry_test.exs`
- `test/drink_water_web/controllers/health_controller_test.exs`
- `test/drink_water_web/plugs/log_metadata_test.exs`
- `test/drink_water/telemetry_events_test.exs`
- `test/drink_water/prom_ex_test.exs`
- `test/drink_water/otel_setup_test.exs`

**Modified files (12):**

- `mix.exs`
- `lib/drink_water/application.ex`
- `lib/drink_water_web/telemetry.ex`
- `lib/drink_water_web/router.ex`
- `lib/drink_water/hydration_tracking.ex`
- `lib/drink_water/user_management.ex`
- `config/config.exs`
- `config/dev.exs`
- `config/prod.exs`
- `config/test.exs`
- `config/runtime.exs`
- `.gitignore`
