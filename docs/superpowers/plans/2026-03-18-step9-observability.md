# Step 9: Observability — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add observability to the drink_water Phoenix app — telemetry, structured logging, custom domain events, Prometheus metrics, distributed tracing, and health check.

**Architecture:** Seven incremental commits (9a→9b→9i→9c→9d→9e→9f). Each commit passes `mix precommit`. OTP native logger handlers for dual output (console + JSON file). `:telemetry.span/3` wrapping all 11 context operations for count + duration measurement. PromEx for Prometheus export on port 4021. OpenTelemetry with exporter `:none` in dev/test.

**Tech Stack:** Phoenix 1.8.5, Elixir 1.19, telemetry_metrics, telemetry_poller, LoggerJSON 7.x, PromEx 1.11, OpenTelemetry 1.7

**Spec:** `docs/superpowers/specs/2026-03-18-step9-observability-design.md`

---

## File Map

| File                                                          | Action | Responsibility                                 | Task          |
| ------------------------------------------------------------- | ------ | ---------------------------------------------- | ------------- |
| `lib/drink_water_web/telemetry.ex`                            | Modify | Telemetry metrics definitions                  | 1, 5          |
| `mix.exs`                                                     | Modify | Deps, extra_applications, ignore_modules       | 1, 2, 4, 5, 6 |
| `test/drink_water_web/telemetry_test.exs`                     | Create | Telemetry module tests                         | 1             |
| `lib/drink_water_web/controllers/health_controller.ex`        | Create | Health check endpoint                          | 3             |
| `test/drink_water_web/controllers/health_controller_test.exs` | Create | Health check tests                             | 3             |
| `lib/drink_water_web/router.ex`                               | Modify | Routes, API pipeline plugs                     | 3, 4          |
| `config/prod.exs`                                             | Modify | force_ssl exclude, JSON logger, PromEx disable | 3, 4, 6       |
| `lib/drink_water_web/plugs/log_metadata.ex`                   | Create | Logger metadata plug                           | 4             |
| `test/drink_water_web/plugs/log_metadata_test.exs`            | Create | LogMetadata plug tests                         | 4             |
| `lib/drink_water/application.ex`                              | Modify | Logger.add_handlers, PromEx child, OtelSetup   | 4, 6, 7       |
| `config/config.exs`                                           | Modify | Logger metadata, PromEx config                 | 4, 6          |
| `config/dev.exs`                                              | Modify | JSON file handler, OTel exporter :none         | 4, 7          |
| `config/test.exs`                                             | Modify | PromEx disabled, OTel exporter :none           | 6, 7          |
| `config/runtime.exs`                                          | Modify | OTel prod config                               | 7             |
| `.gitignore`                                                  | Modify | Ignore logs/                                   | 4             |
| `lib/drink_water/telemetry_events.ex`                         | Create | Custom telemetry span wrappers                 | 5             |
| `test/drink_water/telemetry_events_test.exs`                  | Create | Telemetry event tests                          | 5             |
| `lib/drink_water/hydration_tracking.ex`                       | Modify | Wrap 5 operations with spans                   | 5             |
| `lib/drink_water/user_management.ex`                          | Modify | Wrap 6 operations with spans                   | 5             |
| `lib/drink_water/prom_ex.ex`                                  | Create | PromEx module                                  | 6             |
| `test/drink_water/prom_ex_test.exs`                           | Create | PromEx config tests                            | 6             |
| `lib/drink_water/otel_setup.ex`                               | Create | OpenTelemetry instrumenter setup               | 7             |
| `test/drink_water/otel_setup_test.exs`                        | Create | OtelSetup smoke tests                          | 7             |

---

## Task 1: Telemetry Foundation Enhancement (9a)

**Files:**

- Modify: `lib/drink_water_web/telemetry.ex`
- Modify: `mix.exs`
- Create: `test/drink_water_web/telemetry_test.exs`

- [ ] **Step 1: Write failing tests for telemetry metrics**

Create `test/drink_water_web/telemetry_test.exs`:

```elixir
defmodule DrinkWaterWeb.TelemetryTest do
  use ExUnit.Case, async: true

  alias DrinkWaterWeb.Telemetry

  describe "metrics/0" do
    test "returns a list of telemetry metric definitions" do
      metrics = Telemetry.metrics()
      assert is_list(metrics)
      assert length(metrics) > 0

      assert Enum.all?(metrics, fn metric ->
        is_struct(metric, Telemetry.Metrics.Summary) or
          is_struct(metric, Telemetry.Metrics.Sum) or
          is_struct(metric, Telemetry.Metrics.Counter)
      end)
    end

    test "includes Phoenix endpoint metrics" do
      metrics = Telemetry.metrics()
      names = Enum.map(metrics, fn m -> Enum.join(m.name, ".") end)
      assert Enum.any?(names, &String.starts_with?(&1, "phoenix.endpoint"))
    end

    test "includes Ecto repo metrics" do
      metrics = Telemetry.metrics()
      names = Enum.map(metrics, fn m -> Enum.join(m.name, ".") end)
      assert Enum.any?(names, &String.starts_with?(&1, "drink_water.repo"))
    end

    test "includes VM metrics" do
      metrics = Telemetry.metrics()
      names = Enum.map(metrics, fn m -> Enum.join(m.name, ".") end)
      assert Enum.any?(names, &String.starts_with?(&1, "vm."))
    end

    test "includes LiveView metrics" do
      metrics = Telemetry.metrics()
      names = Enum.map(metrics, fn m -> Enum.join(m.name, ".") end)
      assert Enum.any?(names, &String.starts_with?(&1, "phoenix.live_view"))
    end
  end

  describe "init/1" do
    test "returns supervisor spec with telemetry_poller child" do
      assert {:ok, {%{strategy: :one_for_one}, children}} = Telemetry.init([])
      assert is_list(children)
      assert length(children) > 0
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/drink_water_web/telemetry_test.exs --trace`
Expected: FAIL — LiveView metrics test fails (not yet added)

- [ ] **Step 3: Add LiveView metrics to telemetry.ex**

In `lib/drink_water_web/telemetry.ex`, add after the channel_handled_in metric (after line 53):

```elixir
      # LiveView Metrics
      summary("phoenix.live_view.mount.stop.duration",
        unit: {:native, :millisecond},
        tags: [:view]
      ),
      summary("phoenix.live_view.handle_event.stop.duration",
        unit: {:native, :millisecond},
        tags: [:event]
      ),
      summary("phoenix.live_view.handle_params.stop.duration",
        unit: {:native, :millisecond},
        tags: [:view]
      ),
```

- [ ] **Step 4: Remove DrinkWaterWeb.Telemetry from ignore_modules in mix.exs**

In `mix.exs`, remove `DrinkWaterWeb.Telemetry,` from the `ignore_modules` list (line 24).

- [ ] **Step 5: Run tests to verify they pass**

Run: `mix test test/drink_water_web/telemetry_test.exs --trace`
Expected: ALL PASS

- [ ] **Step 6: Run mix precommit and commit**

Run: `mix precommit`
Expected: All tests pass, zero warnings

```bash
git add lib/drink_water_web/telemetry.ex mix.exs test/drink_water_web/telemetry_test.exs
git commit -m "Add LiveView telemetry metrics and tests (Step 9a)"
```

---

## Task 2: LiveDashboard Extra Panels (9b)

**Files:**

- Modify: `mix.exs`

- [ ] **Step 1: Add :os_mon to extra_applications**

In `mix.exs` `application/0`, change:

```elixir
extra_applications: [:logger, :runtime_tools]
```

to:

```elixir
extra_applications: [:logger, :runtime_tools, :os_mon]
```

- [ ] **Step 2: Run mix precommit**

Run: `mix precommit`
Expected: All tests pass, zero warnings

- [ ] **Step 3: Commit**

```bash
git add mix.exs
git commit -m "Enable OS Data panel in LiveDashboard via :os_mon (Step 9b)"
```

---

## Task 3: Health Check Endpoint (9i)

**Files:**

- Create: `lib/drink_water_web/controllers/health_controller.ex`
- Create: `test/drink_water_web/controllers/health_controller_test.exs`
- Modify: `lib/drink_water_web/router.ex`
- Modify: `config/prod.exs`

- [ ] **Step 1: Write failing tests for health endpoint**

Create `test/drink_water_web/controllers/health_controller_test.exs`:

```elixir
defmodule DrinkWaterWeb.HealthControllerTest do
  use DrinkWaterWeb.ConnCase

  describe "GET /api/health" do
    test "returns 200 with healthy status when DB is reachable", %{conn: conn} do
      conn = get(conn, ~p"/api/health")
      response = json_response(conn, 200)

      assert response["status"] == "healthy"
      assert response["checks"]["database"] == "ok"

      beam = response["checks"]["beam"]
      assert is_integer(beam["uptime_seconds"])
      assert is_integer(beam["memory_mb"])
      assert is_integer(beam["process_count"])
      assert is_integer(beam["schedulers"])
      assert beam["schedulers"] > 0
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/drink_water_web/controllers/health_controller_test.exs --trace`
Expected: FAIL — route not found

- [ ] **Step 3: Add health route to router**

In `lib/drink_water_web/router.ex`, add a new scope BEFORE the existing rate-limited `/api/users` scopes (after line 16, the `:api` pipeline definition):

```elixir
  scope "/api", DrinkWaterWeb do
    pipe_through :api

    get "/health", HealthController, :index
  end
```

- [ ] **Step 4: Create HealthController**

Create `lib/drink_water_web/controllers/health_controller.ex`:

```elixir
defmodule DrinkWaterWeb.HealthController do
  use DrinkWaterWeb, :controller

  def index(conn, _params) do
    db_status = check_db()
    status_code = if db_status == :ok, do: 200, else: 503
    overall = if db_status == :ok, do: :healthy, else: :degraded

    conn
    |> put_status(status_code)
    |> json(%{
      status: overall,
      checks: %{
        database: db_status,
        beam: %{
          uptime_seconds: :erlang.statistics(:wall_clock) |> elem(0) |> div(1000),
          memory_mb: :erlang.memory(:total) |> div(1_048_576),
          process_count: :erlang.system_info(:process_count),
          schedulers: :erlang.system_info(:schedulers_online)
        }
      }
    })
  end

  defp check_db do
    case Ecto.Adapters.SQL.query(DrinkWater.Repo, "SELECT 1", []) do
      {:ok, _} -> :ok
      {:error, _} -> :error
    end
  end
end
```

- [ ] **Step 5: Run test to verify it passes**

Run: `mix test test/drink_water_web/controllers/health_controller_test.exs --trace`
Expected: PASS

- [ ] **Step 6: Uncomment health path in prod.exs force_ssl**

In `config/prod.exs`, change:

```elixir
    exclude: [
      # paths: ["/health"],
      hosts: ["localhost", "127.0.0.1"]
    ]
```

to:

```elixir
    exclude: [
      paths: ["/api/health"],
      hosts: ["localhost", "127.0.0.1"]
    ]
```

- [ ] **Step 7: Run mix precommit and commit**

Run: `mix precommit`
Expected: All tests pass, zero warnings

```bash
git add lib/drink_water_web/controllers/health_controller.ex test/drink_water_web/controllers/health_controller_test.exs lib/drink_water_web/router.ex config/prod.exs
git commit -m "Add health check endpoint GET /api/health (Step 9i)"
```

---

## Task 4: Structured JSON Logging (9c)

**Files:**

- Create: `lib/drink_water_web/plugs/log_metadata.ex`
- Create: `test/drink_water_web/plugs/log_metadata_test.exs`
- Modify: `mix.exs`, `lib/drink_water/application.ex`, `config/config.exs`, `config/dev.exs`, `config/prod.exs`, `lib/drink_water_web/router.ex`, `.gitignore`

- [ ] **Step 1: Add logger_json dependency**

In `mix.exs` `deps/0`, add:

```elixir
{:logger_json, "~> 7.0"},
```

Run: `mix deps.get`

- [ ] **Step 2: Write failing tests for LogMetadata plug**

Create `test/drink_water_web/plugs/log_metadata_test.exs`:

```elixir
defmodule DrinkWaterWeb.Plugs.LogMetadataTest do
  use DrinkWaterWeb.ConnCase, async: true

  alias DrinkWaterWeb.Plugs.LogMetadata

  describe "call/2" do
    test "sets user_id metadata from user_id param", %{conn: conn} do
      conn = %{conn | params: %{"user_id" => "42"}}
      LogMetadata.call(conn, [])
      assert Logger.metadata()[:user_id] == "42"
    end

    test "sets user_id metadata from id param when user_id absent", %{conn: conn} do
      conn = %{conn | params: %{"id" => "99"}}
      LogMetadata.call(conn, [])
      assert Logger.metadata()[:user_id] == "99"
    end

    test "prefers user_id over id when both present", %{conn: conn} do
      conn = %{conn | params: %{"user_id" => "42", "id" => "99"}}
      LogMetadata.call(conn, [])
      assert Logger.metadata()[:user_id] == "42"
    end

    test "does not crash when no user_id or id param", %{conn: conn} do
      conn = %{conn | params: %{}}
      result = LogMetadata.call(conn, [])
      assert result == conn
    end

    test "returns conn unchanged", %{conn: conn} do
      conn = %{conn | params: %{"user_id" => "42"}}
      assert LogMetadata.call(conn, []) == conn
    end
  end

  describe "init/1" do
    test "passes options through" do
      assert LogMetadata.init(foo: :bar) == [foo: :bar]
    end
  end
end
```

- [ ] **Step 3: Run test to verify it fails**

Run: `mix test test/drink_water_web/plugs/log_metadata_test.exs --trace`
Expected: FAIL — module not found

- [ ] **Step 4: Create LogMetadata plug**

Create `lib/drink_water_web/plugs/log_metadata.ex`:

```elixir
defmodule DrinkWaterWeb.Plugs.LogMetadata do
  @moduledoc "Sets Logger metadata from route params for structured logging."

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

- [ ] **Step 5: Run test to verify it passes**

Run: `mix test test/drink_water_web/plugs/log_metadata_test.exs --trace`
Expected: ALL PASS

- [ ] **Step 6: Add LogMetadata plug to API pipeline in router**

In `lib/drink_water_web/router.ex`, modify the `:api` pipeline:

```elixir
  pipeline :api do
    plug :accepts, ["json"]
    plug DrinkWaterWeb.Plugs.InputSanitizer
    plug DrinkWaterWeb.Plugs.LogMetadata
  end
```

- [ ] **Step 7: Update config files**

In `config/config.exs`, change:

```elixir
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]
```

to:

```elixir
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :user_id]
```

In `config/dev.exs`, add at the end (before any trailing comments):

```elixir
# JSON file handler for structured logging (logs/dev.log)
config :drink_water, :logger, [
  {:handler, :file_json, :logger_std_h, %{
    config: %{file: ~c"logs/dev.log", max_no_bytes: 10_485_760, max_no_files: 3},
    formatter: LoggerJSON.Formatters.Basic.new(metadata: [:request_id, :user_id])
  }}
]
```

In `config/prod.exs`, add after `config :logger, level: :info`:

```elixir
# Structured JSON logging to stdout for production log aggregation
config :logger, :default_handler,
  formatter: {LoggerJSON.Formatters.Basic, metadata: [:request_id, :user_id]}
```

- [ ] **Step 8: Add Logger.add_handlers to Application.start**

In `lib/drink_water/application.ex`, add as first line in `start/2`:

```elixir
  def start(_type, _args) do
    Logger.add_handlers(:drink_water)

    children = [
```

Add `require Logger` at the top of the module (after `@moduledoc false`).

- [ ] **Step 9: Add logs/ to .gitignore**

Append to `.gitignore`:

```
# Log files
/logs/
```

- [ ] **Step 10: Create logs directory**

Run: `mkdir -p logs`

- [ ] **Step 11: Run mix precommit and commit**

Run: `mix precommit`
Expected: All tests pass, zero warnings

```bash
git add mix.exs mix.lock lib/drink_water_web/plugs/log_metadata.ex test/drink_water_web/plugs/log_metadata_test.exs lib/drink_water_web/router.ex lib/drink_water/application.ex config/config.exs config/dev.exs config/prod.exs .gitignore
git commit -m "Add structured JSON logging with LoggerJSON and LogMetadata plug (Step 9c)"
```

---

## Task 5: Custom Telemetry Events (9d)

**Files:**

- Create: `lib/drink_water/telemetry_events.ex`
- Create: `test/drink_water/telemetry_events_test.exs`
- Modify: `lib/drink_water/hydration_tracking.ex`
- Modify: `lib/drink_water/user_management.ex`
- Modify: `lib/drink_water_web/telemetry.ex`

- [ ] **Step 1: Write failing tests for TelemetryEvents module**

Create `test/drink_water/telemetry_events_test.exs`:

```elixir
defmodule DrinkWater.TelemetryEventsTest do
  use ExUnit.Case, async: true

  alias DrinkWater.TelemetryEvents

  setup do
    test_pid = self()
    ref = make_ref()

    handler_fn = fn event, measurements, metadata, _config ->
      send(test_pid, {:telemetry, ref, event, measurements, metadata})
    end

    %{handler_fn: handler_fn, ref: ref}
  end

  describe "span_intake_created/2" do
    test "emits :stop event with duration and metadata", %{handler_fn: handler_fn, ref: ref} do
      :telemetry.attach("test-intake-created-#{ref}", [:drink_water, :hydration, :intake_created, :stop], handler_fn, nil)
      on_exit(fn -> :telemetry.detach("test-intake-created-#{ref}") end)

      result = TelemetryEvents.span_intake_created(%{user_id: 1}, fn ->
        {{:ok, :created}, %{volume: 250}}
      end)

      assert result == {:ok, :created}
      assert_receive {:telemetry, ^ref, [:drink_water, :hydration, :intake_created, :stop], measurements, %{user_id: 1}}
      assert is_integer(measurements.duration)
      assert measurements.duration >= 0
    end
  end

  describe "span_intake_updated/2" do
    test "emits :stop event with duration", %{handler_fn: handler_fn, ref: ref} do
      :telemetry.attach("test-intake-updated-#{ref}", [:drink_water, :hydration, :intake_updated, :stop], handler_fn, nil)
      on_exit(fn -> :telemetry.detach("test-intake-updated-#{ref}") end)

      TelemetryEvents.span_intake_updated(%{user_id: 1}, fn -> {:ok, %{}} end)

      assert_receive {:telemetry, ^ref, [:drink_water, :hydration, :intake_updated, :stop], %{duration: _}, %{user_id: 1}}
    end
  end

  describe "span_intake_deleted/2" do
    test "emits :stop event with duration", %{handler_fn: handler_fn, ref: ref} do
      :telemetry.attach("test-intake-deleted-#{ref}", [:drink_water, :hydration, :intake_deleted, :stop], handler_fn, nil)
      on_exit(fn -> :telemetry.detach("test-intake-deleted-#{ref}") end)

      TelemetryEvents.span_intake_deleted(%{user_id: 1}, fn -> {:ok, %{}} end)

      assert_receive {:telemetry, ^ref, [:drink_water, :hydration, :intake_deleted, :stop], %{duration: _}, %{user_id: 1}}
    end
  end

  describe "span_intake_search/2" do
    test "emits :stop event with duration", %{handler_fn: handler_fn, ref: ref} do
      :telemetry.attach("test-intake-search-#{ref}", [:drink_water, :hydration, :intake_search, :stop], handler_fn, nil)
      on_exit(fn -> :telemetry.detach("test-intake-search-#{ref}") end)

      TelemetryEvents.span_intake_search(%{user_id: 1}, fn -> {:ok, %{}} end)

      assert_receive {:telemetry, ^ref, [:drink_water, :hydration, :intake_search, :stop], %{duration: _}, %{user_id: 1}}
    end
  end

  describe "span_user_created/2" do
    test "emits :stop event with duration", %{handler_fn: handler_fn, ref: ref} do
      :telemetry.attach("test-user-created-#{ref}", [:drink_water, :users, :user_created, :stop], handler_fn, nil)
      on_exit(fn -> :telemetry.detach("test-user-created-#{ref}") end)

      TelemetryEvents.span_user_created(%{}, fn -> {:ok, %{}} end)

      assert_receive {:telemetry, ^ref, [:drink_water, :users, :user_created, :stop], %{duration: _}, %{}}
    end
  end

  describe "span_user_deleted/2" do
    test "emits :stop event with duration", %{handler_fn: handler_fn, ref: ref} do
      :telemetry.attach("test-user-deleted-#{ref}", [:drink_water, :users, :user_deleted, :stop], handler_fn, nil)
      on_exit(fn -> :telemetry.detach("test-user-deleted-#{ref}") end)

      TelemetryEvents.span_user_deleted(%{user_id: 1}, fn -> {:ok, %{}} end)

      assert_receive {:telemetry, ^ref, [:drink_water, :users, :user_deleted, :stop], %{duration: _}, %{user_id: 1}}
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/drink_water/telemetry_events_test.exs --trace`
Expected: FAIL — module not found

- [ ] **Step 3: Create TelemetryEvents module**

Create `lib/drink_water/telemetry_events.ex`:

```elixir
defmodule DrinkWater.TelemetryEvents do
  @moduledoc """
  Custom telemetry event wrappers using :telemetry.span/3.

  Each span_* function wraps a business operation and automatically emits
  :start, :stop (with duration), and :exception events.

  The wrapped function must return {result, extra_measurements}.
  """

  # Hydration events

  def span_intake_created(metadata, fun) do
    :telemetry.span([:drink_water, :hydration, :intake_created], metadata, fun)
  end

  def span_intake_updated(metadata, fun) do
    :telemetry.span([:drink_water, :hydration, :intake_updated], metadata, fun)
  end

  def span_intake_deleted(metadata, fun) do
    :telemetry.span([:drink_water, :hydration, :intake_deleted], metadata, fun)
  end

  def span_intake_search(metadata, fun) do
    :telemetry.span([:drink_water, :hydration, :intake_search], metadata, fun)
  end

  # User management events

  def span_user_created(metadata, fun) do
    :telemetry.span([:drink_water, :users, :user_created], metadata, fun)
  end

  def span_user_updated(metadata, fun) do
    :telemetry.span([:drink_water, :users, :user_updated], metadata, fun)
  end

  def span_user_deleted(metadata, fun) do
    :telemetry.span([:drink_water, :users, :user_deleted], metadata, fun)
  end

  def span_alarm_settings_created(metadata, fun) do
    :telemetry.span([:drink_water, :users, :alarm_settings_created], metadata, fun)
  end

  def span_alarm_settings_updated(metadata, fun) do
    :telemetry.span([:drink_water, :users, :alarm_settings_updated], metadata, fun)
  end

  def span_alarm_settings_deleted(metadata, fun) do
    :telemetry.span([:drink_water, :users, :alarm_settings_deleted], metadata, fun)
  end
end
```

- [ ] **Step 4: Run TelemetryEvents tests to verify they pass**

Run: `mix test test/drink_water/telemetry_events_test.exs --trace`
Expected: ALL PASS

- [ ] **Step 5: Wrap HydrationTracking context operations with spans**

Modify `lib/drink_water/hydration_tracking.ex`. Add alias at top:

```elixir
alias DrinkWater.TelemetryEvents
```

Wrap `list_water_intakes/2` — the function body becomes the span callback:

```elixir
def list_water_intakes(user_id, params \\ %{}) do
  TelemetryEvents.span_intake_search(%{user_id: user_id}, fn ->
    result =
      with {:ok, filter} <- WaterIntakeFilter.changeset(params) |> apply_action(:validate),
           {:ok, query} <-
             WaterIntake
             |> where(user_id: ^user_id)
             |> apply_date_filter(filter)
             |> apply_volume_filter(filter)
             |> apply_cursor(filter) do
        entries =
          query
          |> apply_sort(filter)
          |> limit(^(filter.size + 1))
          |> Repo.all()

        {page, next_cursor} = build_page(entries, filter)
        {:ok, %{entries: page, next_cursor: next_cursor}}
      end

    {result, %{}}
  end)
end
```

Similarly wrap `create_water_intake/2`:

```elixir
def create_water_intake(user_id, attrs) do
  TelemetryEvents.span_intake_created(%{user_id: user_id}, fn ->
    result =
      %WaterIntake{user_id: user_id}
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

Wrap `update_water_intake/2`:

```elixir
def update_water_intake(%WaterIntake{} = water_intake, attrs) do
  TelemetryEvents.span_intake_updated(%{user_id: water_intake.user_id}, fn ->
    result =
      water_intake
      |> WaterIntake.changeset(attrs)
      |> Repo.update()
      |> maybe_conflict(:water_intake)

    case result do
      {:ok, updated} ->
        broadcast_event(updated.user_id, :intake_updated)
        {result, %{}}

      _ ->
        {result, %{}}
    end
  end)
end
```

Wrap `delete_water_intake/1`:

```elixir
def delete_water_intake(%WaterIntake{} = water_intake) do
  TelemetryEvents.span_intake_deleted(%{user_id: water_intake.user_id}, fn ->
    {:ok, deleted} = Repo.delete(water_intake)
    broadcast_event(deleted.user_id, :intake_deleted)
    {{:ok, deleted}, %{}}
  end)
end
```

Wrap `delete_water_intake_by_id/2`:

```elixir
def delete_water_intake_by_id(user_id, intake_id) do
  TelemetryEvents.span_intake_deleted(%{user_id: user_id}, fn ->
    result =
      with {:ok, intake} <- get_water_intake(user_id, intake_id),
           {:ok, deleted} <- Repo.delete(intake) do
        broadcast_event(user_id, :intake_deleted)
        {:ok, deleted}
      end

    {result, %{}}
  end)
end
```

- [ ] **Step 6: Wrap UserManagement context operations with spans**

Modify `lib/drink_water/user_management.ex`. Add alias at top:

```elixir
alias DrinkWater.TelemetryEvents
```

Wrap `create_user/1`:

```elixir
def create_user(attrs) do
  TelemetryEvents.span_user_created(%{}, fn ->
    result =
      %User{}
      |> User.changeset(attrs)
      |> Repo.insert()
      |> maybe_conflict(:user, :email)

    {result, %{}}
  end)
end
```

Wrap `update_user/2`:

```elixir
def update_user(%User{} = user, attrs) do
  TelemetryEvents.span_user_updated(%{user_id: user.id}, fn ->
    result =
      user
      |> User.changeset(attrs)
      |> Repo.update()

    {result, %{}}
  end)
end
```

Wrap `delete_user_by_id/1` (integer clause) — note: returns bare `:ok`, span result must be discarded to preserve contract:

```elixir
def delete_user_by_id(id) when is_integer(id) do
  TelemetryEvents.span_user_deleted(%{user_id: id}, fn ->
    User
    |> where(id: ^id)
    |> Repo.delete_all()

    {:ok, %{}}
  end)

  :ok
end
```

Wrap `create_alarm_settings/2`:

```elixir
def create_alarm_settings(%User{} = user, attrs) do
  TelemetryEvents.span_alarm_settings_created(%{user_id: user.id}, fn ->
    result =
      user
      |> Ecto.build_assoc(:alarm_settings)
      |> AlarmSettings.changeset(attrs)
      |> Repo.insert()
      |> maybe_conflict(:alarm_settings, :user_id)

    {result, %{}}
  end)
end
```

Wrap `update_alarm_settings/2`:

```elixir
def update_alarm_settings(%AlarmSettings{} = alarm_settings, attrs) do
  TelemetryEvents.span_alarm_settings_updated(%{user_id: alarm_settings.user_id}, fn ->
    result =
      alarm_settings
      |> AlarmSettings.changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, updated} ->
        Phoenix.PubSub.broadcast(
          DrinkWater.PubSub,
          "user:#{updated.user_id}",
          :alarm_settings_updated
        )

        {result, %{}}

      _ ->
        {result, %{}}
    end
  end)
end
```

Wrap `delete_alarm_settings/1`:

```elixir
def delete_alarm_settings(%AlarmSettings{} = alarm_settings) do
  TelemetryEvents.span_alarm_settings_deleted(%{user_id: alarm_settings.user_id}, fn ->
    result = Repo.delete(alarm_settings)
    {result, %{}}
  end)
end
```

- [ ] **Step 7: Add domain metrics to telemetry.ex**

In `lib/drink_water_web/telemetry.ex` `metrics/0`, add after the VM metrics block:

```elixir
      # Domain Metrics — Hydration
      summary("drink_water.hydration.intake_created.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("drink_water.hydration.intake_updated.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("drink_water.hydration.intake_deleted.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("drink_water.hydration.intake_search.stop.duration",
        unit: {:native, :millisecond}
      ),

      # Domain Metrics — Users
      summary("drink_water.users.user_created.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("drink_water.users.user_updated.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("drink_water.users.user_deleted.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("drink_water.users.alarm_settings_created.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("drink_water.users.alarm_settings_updated.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("drink_water.users.alarm_settings_deleted.stop.duration",
        unit: {:native, :millisecond}
      )
```

- [ ] **Step 8: Run full test suite**

Run: `mix precommit`
Expected: All tests pass, zero warnings. Existing context tests must still pass since span wrapping is transparent.

- [ ] **Step 9: Commit**

```bash
git add lib/drink_water/telemetry_events.ex test/drink_water/telemetry_events_test.exs lib/drink_water/hydration_tracking.ex lib/drink_water/user_management.ex lib/drink_water_web/telemetry.ex
git commit -m "Add custom telemetry events with span instrumentation for all context operations (Step 9d)"
```

---

## Task 6: Prometheus Metrics Export — PromEx (9e)

**Files:**

- Create: `lib/drink_water/prom_ex.ex`
- Create: `test/drink_water/prom_ex_test.exs`
- Modify: `mix.exs`, `lib/drink_water/application.ex`, `config/config.exs`, `config/test.exs`, `config/prod.exs`

- [ ] **Step 1: Add prom_ex dependency**

In `mix.exs` `deps/0`, add:

```elixir
{:prom_ex, "~> 1.11"},
```

Run: `mix deps.get`

- [ ] **Step 2: Write tests for PromEx module**

Create `test/drink_water/prom_ex_test.exs`:

```elixir
defmodule DrinkWater.PromExTest do
  use ExUnit.Case, async: true

  alias DrinkWater.PromEx

  describe "plugins/0" do
    test "returns list with Application, Beam, Phoenix, and Ecto plugins" do
      plugins = PromEx.plugins()
      assert length(plugins) == 4

      plugin_modules =
        Enum.map(plugins, fn
          {mod, _opts} -> mod
          mod -> mod
        end)

      assert PromEx.Plugins.Application in plugin_modules
      assert PromEx.Plugins.Beam in plugin_modules
      assert PromEx.Plugins.Phoenix in plugin_modules
      assert PromEx.Plugins.Ecto in plugin_modules
    end
  end

  describe "dashboards/0" do
    test "returns list of dashboard tuples" do
      dashboards = PromEx.dashboards()
      assert length(dashboards) == 4
      assert {:prom_ex, "application.json"} in dashboards
      assert {:prom_ex, "beam.json"} in dashboards
      assert {:prom_ex, "phoenix.json"} in dashboards
      assert {:prom_ex, "ecto.json"} in dashboards
    end
  end

  describe "dashboard_assigns/0" do
    test "includes datasource_id" do
      assigns = PromEx.dashboard_assigns()
      assert Keyword.get(assigns, :datasource_id) == "prometheus"
    end
  end
end
```

- [ ] **Step 3: Run test to verify it fails**

Run: `mix test test/drink_water/prom_ex_test.exs --trace`
Expected: FAIL — module not found

- [ ] **Step 4: Create PromEx module**

Create `lib/drink_water/prom_ex.ex`:

```elixir
defmodule DrinkWater.PromEx do
  @moduledoc "Prometheus metrics exporter using PromEx plugins."

  use PromEx, otp_app: :drink_water

  alias PromEx.Plugins

  @impl true
  def plugins do
    [
      Plugins.Application,
      Plugins.Beam,
      {Plugins.Phoenix, router: DrinkWaterWeb.Router, endpoint: DrinkWaterWeb.Endpoint},
      {Plugins.Ecto, repos: [DrinkWater.Repo]}
    ]
  end

  @impl true
  def dashboard_assigns do
    [datasource_id: "prometheus", default_selected_interval: "30s"]
  end

  @impl true
  def dashboards do
    [
      {:prom_ex, "application.json"},
      {:prom_ex, "beam.json"},
      {:prom_ex, "phoenix.json"},
      {:prom_ex, "ecto.json"}
    ]
  end
end
```

- [ ] **Step 5: Add PromEx config**

In `config/config.exs`, add before the `import_config` line:

```elixir
# PromEx Prometheus metrics
config :drink_water, DrinkWater.PromEx,
  disabled: false,
  manual_metrics_start_delay: :no_delay,
  drop_metrics_groups: [],
  grafana: :disabled,
  metrics_server: [port: 4021, path: "/metrics"]
```

In `config/test.exs`, add:

```elixir
# Disable PromEx metrics server in test
config :drink_water, DrinkWater.PromEx, disabled: true
```

In `config/prod.exs`, add:

```elixir
# Disable PromEx metrics_server in prod (expose via authenticated Plug instead)
config :drink_water, DrinkWater.PromEx,
  metrics_server: :disabled
```

- [ ] **Step 6: Add PromEx to supervision tree**

In `lib/drink_water/application.ex`, add `DrinkWater.PromEx` to children list before `DrinkWaterWeb.Endpoint`:

```elixir
    children = [
      DrinkWaterWeb.Telemetry,
      DrinkWater.Repo,
      {DNSCluster, query: Application.get_env(:drink_water, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: DrinkWater.PubSub},
      {DrinkWater.RateLimit, clean_period: :timer.minutes(1)},
      DrinkWater.PromEx,
      DrinkWaterWeb.Endpoint
    ]
```

- [ ] **Step 7: Add PromEx to ignore_modules in mix.exs**

In `mix.exs`, add `DrinkWater.PromEx` to the `ignore_modules` list:

```elixir
test_coverage: [
  ignore_modules: [
    DrinkWaterWeb.PageHTML,
    DrinkWaterWeb.ErrorHTML,
    DrinkWater.DataCase,
    DrinkWater.Repo,
    DrinkWater.Application,
    DrinkWater.PromEx,
    DrinkWaterWeb.Layouts
  ]
]
```

- [ ] **Step 8: Run tests to verify pass**

Run: `mix test test/drink_water/prom_ex_test.exs --trace`
Expected: ALL PASS

- [ ] **Step 9: Run mix precommit and commit**

Run: `mix precommit`
Expected: All tests pass, zero warnings

```bash
git add lib/drink_water/prom_ex.ex test/drink_water/prom_ex_test.exs mix.exs mix.lock lib/drink_water/application.ex config/config.exs config/test.exs config/prod.exs
git commit -m "Add Prometheus metrics export via PromEx on port 4021 (Step 9e)"
```

---

## Task 7: Request Tracing — OpenTelemetry (9f)

**Files:**

- Create: `lib/drink_water/otel_setup.ex`
- Create: `test/drink_water/otel_setup_test.exs`
- Modify: `mix.exs`, `lib/drink_water/application.ex`, `config/dev.exs`, `config/test.exs`, `config/runtime.exs`

- [ ] **Step 1: Add OpenTelemetry dependencies**

In `mix.exs` `deps/0`, add:

```elixir
{:opentelemetry, "~> 1.7"},
{:opentelemetry_api, "~> 1.5"},
{:opentelemetry_exporter, "~> 1.10"},
{:opentelemetry_phoenix, "~> 2.0"},
{:opentelemetry_ecto, "~> 1.2"},
{:opentelemetry_bandit, "~> 0.3.0"},
```

Run: `mix deps.get`

- [ ] **Step 2: Write tests for OtelSetup**

Create `test/drink_water/otel_setup_test.exs`:

```elixir
defmodule DrinkWater.OtelSetupTest do
  use ExUnit.Case, async: true

  alias DrinkWater.OtelSetup

  describe "setup/0" do
    test "does not raise" do
      assert :ok == OtelSetup.setup()
    end

    test "is idempotent — calling twice does not crash" do
      OtelSetup.setup()
      # Second call should not raise even if handlers are already attached
      assert :ok == OtelSetup.setup()
    end
  end
end
```

- [ ] **Step 3: Run test to verify it fails**

Run: `mix test test/drink_water/otel_setup_test.exs --trace`
Expected: FAIL — module not found

- [ ] **Step 4: Create OtelSetup module**

Create `lib/drink_water/otel_setup.ex`:

```elixir
defmodule DrinkWater.OtelSetup do
  @moduledoc "Attaches OpenTelemetry instrumenters for Phoenix, Ecto, and Bandit."

  def setup do
    OpentelemetryBandit.setup()
    OpentelemetryPhoenix.setup(adapter: :bandit)
    OpentelemetryEcto.setup([:drink_water, :repo])
    :ok
  end
end
```

- [ ] **Step 5: Run test to verify it passes**

Run: `mix test test/drink_water/otel_setup_test.exs --trace`
Expected: ALL PASS

- [ ] **Step 6: Call OtelSetup in Application.start**

In `lib/drink_water/application.ex`, add after `Logger.add_handlers(:drink_water)`:

```elixir
  def start(_type, _args) do
    Logger.add_handlers(:drink_water)
    DrinkWater.OtelSetup.setup()

    children = [
```

- [ ] **Step 7: Configure OpenTelemetry exporters**

In `config/dev.exs`, add:

```elixir
# Disable OpenTelemetry trace export in dev (no collector running)
config :opentelemetry, traces_exporter: :none
```

In `config/test.exs`, add:

```elixir
# Disable OpenTelemetry trace export in test
config :opentelemetry, traces_exporter: :none
```

In `config/runtime.exs`, add inside the `if config_env() == :prod do` block:

```elixir
  # OpenTelemetry tracing
  config :opentelemetry, :resource, service: [name: "drink_water"]

  config :opentelemetry,
    span_processor: :batch,
    traces_exporter:
      {:otlp,
       endpoint:
         System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4318")}
```

- [ ] **Step 8: Run mix precommit and commit**

Run: `mix precommit`
Expected: All tests pass, zero warnings

```bash
git add lib/drink_water/otel_setup.ex test/drink_water/otel_setup_test.exs mix.exs mix.lock lib/drink_water/application.ex config/dev.exs config/test.exs config/runtime.exs
git commit -m "Add OpenTelemetry distributed tracing for Phoenix, Ecto, and Bandit (Step 9f)"
```

---

## Final Verification

After all 7 tasks:

- [ ] `mix precommit` — all tests pass, zero warnings
- [ ] `mix phx.server` — app boots cleanly
- [ ] `curl localhost:4000/api/health` — returns 200 healthy JSON
- [ ] `curl localhost:4021/metrics` — returns Prometheus text format with phoenix*\*, ecto*_, beam\__ metrics
- [ ] Visit `localhost:4000/dev/dashboard` — Metrics, OS Data, Ecto Stats tabs populated
- [ ] Create a water intake via API — verify in `logs/dev.log` that JSON log line appears with request_id and user_id
- [ ] Update MIGRATION_ROADMAP.md — mark completed substeps (9a, 9b, 9c, 9d, 9e, 9f, 9i) and commit:

```bash
git add MIGRATION_ROADMAP.md
git commit -m "Update migration roadmap: mark Step 9 observability substeps complete"
```
