defmodule DrinkWater.OtelSetup do
  @moduledoc "Attaches OpenTelemetry instrumenters for Phoenix, Ecto, and Bandit."

  def setup do
    OpentelemetryBandit.setup()
    OpentelemetryPhoenix.setup(adapter: :bandit)
    OpentelemetryEcto.setup([:drink_water, :repo])
    :ok
  end
end
