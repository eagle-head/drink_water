defmodule DrinkWaterWeb.AlarmSettingsJSON do
  alias DrinkWater.UserManagement.AlarmSettings

  @doc """
  Renders a single alarm_settings.
  """
  def show(%{alarm_settings: alarm_settings}) do
    %{data: data(alarm_settings)}
  end

  defp data(%AlarmSettings{} = alarm_settings) do
    %{
      id: alarm_settings.id,
      goal: alarm_settings.goal,
      interval_minutes: alarm_settings.interval_minutes,
      daily_start_time: alarm_settings.daily_start_time,
      daily_end_time: alarm_settings.daily_end_time
    }
  end
end
