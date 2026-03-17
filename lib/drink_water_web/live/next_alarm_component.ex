defmodule DrinkWaterWeb.NextAlarmComponent do
  use DrinkWaterWeb, :live_component

  alias DrinkWater.UserManagement

  @impl true
  def update(assigns, socket) do
    alarm_settings = load_alarm_settings(assigns.user_id)
    now = Map.get(assigns, :now, Time.utc_now())
    next_alarm = if alarm_settings, do: calculate_next_alarm(alarm_settings, now), else: nil

    {:ok,
     socket
     |> assign(:user_id, assigns.user_id)
     |> assign(:alarm_settings, alarm_settings)
     |> assign(:next_alarm, next_alarm)}
  end

  defp load_alarm_settings(user_id) do
    case UserManagement.get_alarm_settings_by_user(user_id) do
      {:ok, settings} -> settings
      {:error, :not_found, :alarm_settings} -> nil
    end
  end

  defp calculate_next_alarm(settings, now) do
    start_time = settings.daily_start_time
    end_time = settings.daily_end_time
    interval = settings.interval_minutes

    cond do
      Time.compare(now, start_time) == :lt ->
        start_time

      Time.compare(now, end_time) != :lt ->
        nil

      true ->
        minutes_since_start = Time.diff(now, start_time, :minute)
        intervals_passed = div(minutes_since_start, interval)
        next_minutes = (intervals_passed + 1) * interval
        next_time = Time.add(start_time, next_minutes * 60, :second)

        if Time.compare(next_time, end_time) != :gt, do: next_time, else: nil
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h2 class="card-title mb-4">{gettext("Next Alarm")}</h2>
      <%= if @alarm_settings == nil do %>
        <p class="label">{gettext("No alarm configured")}</p>
      <% else %>
        <%= if @next_alarm do %>
          <p class="stat-value text-xl">{Calendar.strftime(@next_alarm, "%H:%M")}</p>
          <p class="label">
            {gettext("Every %{minutes} min", minutes: @alarm_settings.interval_minutes)}
          </p>
          <p class="label text-xs opacity-40">
            {Calendar.strftime(@alarm_settings.daily_start_time, "%H:%M")} → {Calendar.strftime(
              @alarm_settings.daily_end_time,
              "%H:%M"
            )}
          </p>
        <% else %>
          <p class="label">{gettext("Done for today!")}</p>
          <p class="label text-xs opacity-40">
            {gettext("Every %{minutes} min", minutes: @alarm_settings.interval_minutes)}
          </p>
        <% end %>
      <% end %>
    </div>
    """
  end
end
