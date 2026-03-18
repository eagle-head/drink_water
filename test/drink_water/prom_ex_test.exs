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

      assert Elixir.PromEx.Plugins.Application in plugin_modules
      assert Elixir.PromEx.Plugins.Beam in plugin_modules
      assert Elixir.PromEx.Plugins.Phoenix in plugin_modules
      assert Elixir.PromEx.Plugins.Ecto in plugin_modules
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
