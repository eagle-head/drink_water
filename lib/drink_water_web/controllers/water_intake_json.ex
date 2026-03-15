defmodule DrinkWaterWeb.WaterIntakeJSON do
  alias DrinkWater.HydrationTracking.WaterIntake

  @doc """
  Renders a paginated list of water_intakes.
  """
  def index(%{page: %{entries: entries, next_cursor: next_cursor}}) do
    %{
      data: for(water_intake <- entries, do: data(water_intake)),
      next_cursor: next_cursor
    }
  end

  @doc """
  Renders a single water_intake.
  """
  def show(%{water_intake: water_intake}) do
    %{data: data(water_intake)}
  end

  defp data(%WaterIntake{} = water_intake) do
    %{
      id: water_intake.id,
      date_time_utc: water_intake.date_time_utc,
      volume: water_intake.volume,
      volume_unit: water_intake.volume_unit
    }
  end
end
