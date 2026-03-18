defmodule DrinkWaterWeb.TelemetryTest do
  use ExUnit.Case, async: true

  describe "metrics/0" do
    test "returns a list of telemetry metric definitions" do
      metrics = DrinkWaterWeb.Telemetry.metrics()
      assert is_list(metrics)
      assert length(metrics) > 0

      assert Enum.all?(metrics, fn metric ->
               match?(%Telemetry.Metrics.Summary{}, metric) or
                 match?(%Telemetry.Metrics.Sum{}, metric) or
                 match?(%Telemetry.Metrics.Counter{}, metric)
             end)
    end

    test "includes Phoenix endpoint metrics" do
      metrics = DrinkWaterWeb.Telemetry.metrics()
      names = Enum.map(metrics, fn m -> Enum.join(m.name, ".") end)
      assert Enum.any?(names, &String.starts_with?(&1, "phoenix.endpoint"))
    end

    test "includes Ecto repo metrics" do
      metrics = DrinkWaterWeb.Telemetry.metrics()
      names = Enum.map(metrics, fn m -> Enum.join(m.name, ".") end)
      assert Enum.any?(names, &String.starts_with?(&1, "drink_water.repo"))
    end

    test "includes VM metrics" do
      metrics = DrinkWaterWeb.Telemetry.metrics()
      names = Enum.map(metrics, fn m -> Enum.join(m.name, ".") end)
      assert Enum.any?(names, &String.starts_with?(&1, "vm."))
    end

    test "includes LiveView metrics" do
      metrics = DrinkWaterWeb.Telemetry.metrics()
      names = Enum.map(metrics, fn m -> Enum.join(m.name, ".") end)
      assert Enum.any?(names, &String.starts_with?(&1, "phoenix.live_view"))
    end
  end

  describe "init/1" do
    test "returns supervisor spec with telemetry_poller child" do
      assert {:ok, {%{strategy: :one_for_one}, children}} = DrinkWaterWeb.Telemetry.init([])
      assert is_list(children)
      assert length(children) > 0
    end
  end
end
