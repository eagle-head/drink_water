defmodule DrinkWaterWeb.NextAlarmComponent do
  use DrinkWaterWeb, :live_component

  alias DrinkWater.UserManagement

  @impl true
  def update(assigns, socket) do
    alarm_settings = load_alarm_settings(assigns.user_id)
    now = Map.get(assigns, :now, Time.utc_now())

    {next_alarm, countdown} =
      with settings when not is_nil(settings) <- alarm_settings,
           next when not is_nil(next) <- calculate_next_alarm(settings, now) do
        {next, calculate_countdown(next, now)}
      else
        _ -> {nil, nil}
      end

    {:ok,
     socket
     |> assign(:user_id, assigns.user_id)
     |> assign(:alarm_settings, alarm_settings)
     |> assign(:next_alarm, next_alarm)
     |> assign(:countdown, countdown)}
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

        case Time.compare(next_time, end_time) do
          :gt -> nil
          _ok -> next_time
        end
    end
  end

  defp calculate_countdown(next_alarm, now) do
    diff_seconds = Time.diff(next_alarm, now, :second)
    diff_seconds = max(diff_seconds, 0)
    hours = div(diff_seconds, 3600)
    minutes = div(rem(diff_seconds, 3600), 60)
    %{hours: hours, minutes: minutes}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h2 class="card-title mb-4">{gettext("Next Alarm")}</h2>
      <%= if @alarm_settings == nil do %>
        <p class="text-base-content/60">{gettext("No alarm configured")}</p>
      <% else %>
        <%= if @next_alarm do %>
          <div class="flex items-center gap-1 font-mono text-2xl">
            <span class="countdown">
              <span style={"--value:#{@countdown.hours};"}></span>
            </span>
            :
            <span class="countdown">
              <span style={"--value:#{@countdown.minutes};"}></span>
            </span>
          </div>
          <p class="text-sm text-base-content/60 mt-1">
            {gettext("Next at %{time}", time: Calendar.strftime(@next_alarm, "%H:%M"))}
          </p>
          <p class="text-sm text-base-content/60">
            {gettext("Every %{minutes} min", minutes: @alarm_settings.interval_minutes)} · {Calendar.strftime(
              @alarm_settings.daily_start_time,
              "%H:%M"
            )} → {Calendar.strftime(
              @alarm_settings.daily_end_time,
              "%H:%M"
            )}
          </p>
        <% else %>
          <p class="text-base-content/60">{gettext("Done for today!")}</p>
          <p class="text-sm text-base-content/60">
            {gettext("Every %{minutes} min", minutes: @alarm_settings.interval_minutes)}
          </p>
        <% end %>
      <% end %>
    </div>
    """
  end
end
