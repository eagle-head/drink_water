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
