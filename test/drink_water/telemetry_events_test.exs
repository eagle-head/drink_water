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
    test "emits :stop event with duration and extra measurements", %{
      handler_fn: handler_fn,
      ref: ref
    } do
      handler_id = "test-intake-created-#{inspect(ref)}"

      :telemetry.attach(
        handler_id,
        [:drink_water, :hydration, :intake_created, :stop],
        handler_fn,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      result =
        TelemetryEvents.span_intake_created(%{user_id: 1}, fn ->
          {{:ok, :created}, %{volume: 250}, %{user_id: 1}}
        end)

      assert result == {:ok, :created}

      assert_receive {:telemetry, ^ref, [:drink_water, :hydration, :intake_created, :stop],
                      measurements, %{user_id: 1}}

      assert is_integer(measurements.duration)
      assert measurements.duration >= 0
      assert measurements.volume == 250
    end
  end

  describe "span_intake_updated/2" do
    test "emits :stop event with duration", %{handler_fn: handler_fn, ref: ref} do
      handler_id = "test-intake-updated-#{inspect(ref)}"

      :telemetry.attach(
        handler_id,
        [:drink_water, :hydration, :intake_updated, :stop],
        handler_fn,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      TelemetryEvents.span_intake_updated(%{user_id: 1}, fn ->
        {{:ok, %{}}, %{user_id: 1}}
      end)

      assert_receive {:telemetry, ^ref, [:drink_water, :hydration, :intake_updated, :stop],
                      %{duration: _}, %{user_id: 1}}
    end
  end

  describe "span_intake_deleted/2" do
    test "emits :stop event with duration", %{handler_fn: handler_fn, ref: ref} do
      handler_id = "test-intake-deleted-#{inspect(ref)}"

      :telemetry.attach(
        handler_id,
        [:drink_water, :hydration, :intake_deleted, :stop],
        handler_fn,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      TelemetryEvents.span_intake_deleted(%{user_id: 1}, fn ->
        {{:ok, %{}}, %{user_id: 1}}
      end)

      assert_receive {:telemetry, ^ref, [:drink_water, :hydration, :intake_deleted, :stop],
                      %{duration: _}, %{user_id: 1}}
    end
  end

  describe "span_intake_search/2" do
    test "emits :stop event with duration", %{handler_fn: handler_fn, ref: ref} do
      handler_id = "test-intake-search-#{inspect(ref)}"

      :telemetry.attach(
        handler_id,
        [:drink_water, :hydration, :intake_search, :stop],
        handler_fn,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      TelemetryEvents.span_intake_search(%{user_id: 1}, fn ->
        {{:ok, %{}}, %{user_id: 1}}
      end)

      assert_receive {:telemetry, ^ref, [:drink_water, :hydration, :intake_search, :stop],
                      %{duration: _}, %{user_id: 1}}
    end
  end

  describe "span_user_created/2" do
    test "emits :stop event with duration", %{handler_fn: handler_fn, ref: ref} do
      handler_id = "test-user-created-#{inspect(ref)}"

      :telemetry.attach(
        handler_id,
        [:drink_water, :users, :user_created, :stop],
        handler_fn,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      TelemetryEvents.span_user_created(%{}, fn -> {{:ok, %{}}, %{}} end)

      assert_receive {:telemetry, ^ref, [:drink_water, :users, :user_created, :stop],
                      %{duration: _}, %{}}
    end
  end

  describe "span_user_updated/2" do
    test "emits :stop event with duration", %{handler_fn: handler_fn, ref: ref} do
      handler_id = "test-user-updated-#{inspect(ref)}"

      :telemetry.attach(
        handler_id,
        [:drink_water, :users, :user_updated, :stop],
        handler_fn,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      TelemetryEvents.span_user_updated(%{user_id: 1}, fn ->
        {{:ok, %{}}, %{user_id: 1}}
      end)

      assert_receive {:telemetry, ^ref, [:drink_water, :users, :user_updated, :stop],
                      %{duration: _}, %{user_id: 1}}
    end
  end

  describe "span_user_deleted/2" do
    test "emits :stop event with duration", %{handler_fn: handler_fn, ref: ref} do
      handler_id = "test-user-deleted-#{inspect(ref)}"

      :telemetry.attach(
        handler_id,
        [:drink_water, :users, :user_deleted, :stop],
        handler_fn,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      TelemetryEvents.span_user_deleted(%{user_id: 1}, fn ->
        {{:ok, %{}}, %{user_id: 1}}
      end)

      assert_receive {:telemetry, ^ref, [:drink_water, :users, :user_deleted, :stop],
                      %{duration: _}, %{user_id: 1}}
    end
  end

  describe "span_alarm_settings_created/2" do
    test "emits :stop event with duration", %{handler_fn: handler_fn, ref: ref} do
      handler_id = "test-alarm-settings-created-#{inspect(ref)}"

      :telemetry.attach(
        handler_id,
        [:drink_water, :users, :alarm_settings_created, :stop],
        handler_fn,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      TelemetryEvents.span_alarm_settings_created(%{user_id: 1}, fn ->
        {{:ok, %{}}, %{user_id: 1}}
      end)

      assert_receive {:telemetry, ^ref, [:drink_water, :users, :alarm_settings_created, :stop],
                      %{duration: _}, %{user_id: 1}}
    end
  end

  describe "span_alarm_settings_updated/2" do
    test "emits :stop event with duration", %{handler_fn: handler_fn, ref: ref} do
      handler_id = "test-alarm-settings-updated-#{inspect(ref)}"

      :telemetry.attach(
        handler_id,
        [:drink_water, :users, :alarm_settings_updated, :stop],
        handler_fn,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      TelemetryEvents.span_alarm_settings_updated(%{user_id: 1}, fn ->
        {{:ok, %{}}, %{user_id: 1}}
      end)

      assert_receive {:telemetry, ^ref, [:drink_water, :users, :alarm_settings_updated, :stop],
                      %{duration: _}, %{user_id: 1}}
    end
  end

  describe "span_alarm_settings_deleted/2" do
    test "emits :stop event with duration", %{handler_fn: handler_fn, ref: ref} do
      handler_id = "test-alarm-settings-deleted-#{inspect(ref)}"

      :telemetry.attach(
        handler_id,
        [:drink_water, :users, :alarm_settings_deleted, :stop],
        handler_fn,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      TelemetryEvents.span_alarm_settings_deleted(%{user_id: 1}, fn ->
        {{:ok, %{}}, %{user_id: 1}}
      end)

      assert_receive {:telemetry, ^ref, [:drink_water, :users, :alarm_settings_deleted, :stop],
                      %{duration: _}, %{user_id: 1}}
    end
  end
end
