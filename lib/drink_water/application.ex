defmodule DrinkWater.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      DrinkWaterWeb.Telemetry,
      DrinkWater.Repo,
      {DNSCluster, query: Application.get_env(:drink_water, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: DrinkWater.PubSub},
      # Start a worker by calling: DrinkWater.Worker.start_link(arg)
      # {DrinkWater.Worker, arg},
      # Start to serve requests, typically the last entry
      DrinkWaterWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: DrinkWater.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    DrinkWaterWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
