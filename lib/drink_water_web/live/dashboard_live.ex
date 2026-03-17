defmodule DrinkWaterWeb.DashboardLive do
  use DrinkWaterWeb, :live_view

  alias DrinkWater.UserManagement
  alias DrinkWater.HydrationTracking

  # Hardcoded until auth is implemented (Step 10).
  # Configurable via Application env for test isolation.
  @default_goal 2000

  defp hardcoded_user_id do
    Application.get_env(:drink_water, :dashboard_user_id, 1)
  end

  @impl true
  def mount(_params, _session, socket) do
    user_id = hardcoded_user_id()

    if connected?(socket) do
      Phoenix.PubSub.subscribe(DrinkWater.PubSub, "user:#{user_id}")
    end

    {:ok, assign(socket, page_title: gettext("Hydration Dashboard"), user_id: user_id)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    with {:ok, user} <- UserManagement.get_user(socket.assigns.user_id) do
      goal = load_goal(user.id)

      {:noreply,
       socket
       |> assign(user: user, goal: goal, selected_date: Date.utc_today(), editing_intake: nil)}
    else
      {:error, :not_found, :user} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("User not found"))
         |> redirect(to: ~p"/")}
    end
  end

  # Date navigation from child components
  @impl true
  def handle_info({:select_date, date}, socket) do
    send_update(DrinkWaterWeb.ProgressComponent,
      id: "progress",
      user_id: socket.assigns.user.id,
      goal: socket.assigns.goal,
      selected_date: date
    )

    send_update(DrinkWaterWeb.HistoryComponent,
      id: "history",
      user_id: socket.assigns.user.id,
      selected_date: date
    )

    send_update(DrinkWaterWeb.WeeklySummaryComponent,
      id: "weekly-summary",
      user_id: socket.assigns.user.id,
      goal: socket.assigns.goal,
      selected_date: date
    )

    {:noreply, assign(socket, selected_date: date)}
  end

  # Intake events — conditional PubSub guard based on selected_date
  @impl true
  def handle_info(event, socket)
      when event in [:intake_created, :intake_deleted, :intake_updated] do
    # Always update weekly summary
    send_update(DrinkWaterWeb.WeeklySummaryComponent,
      id: "weekly-summary",
      user_id: socket.assigns.user.id,
      goal: socket.assigns.goal,
      selected_date: socket.assigns.selected_date
    )

    # Only update progress/history if viewing today
    if socket.assigns.selected_date == Date.utc_today() do
      send_update(DrinkWaterWeb.ProgressComponent,
        id: "progress",
        user_id: socket.assigns.user.id,
        goal: socket.assigns.goal,
        selected_date: socket.assigns.selected_date
      )

      send_update(DrinkWaterWeb.HistoryComponent,
        id: "history",
        user_id: socket.assigns.user.id,
        selected_date: socket.assigns.selected_date
      )
    end

    {:noreply, socket}
  end

  # Alarm settings — NOT guarded by selected_date (goal change affects all days)
  @impl true
  def handle_info(:alarm_settings_updated, socket) do
    goal = load_goal(socket.assigns.user.id)

    send_update(DrinkWaterWeb.ProgressComponent,
      id: "progress",
      user_id: socket.assigns.user.id,
      goal: goal,
      selected_date: socket.assigns.selected_date
    )

    send_update(DrinkWaterWeb.NextAlarmComponent,
      id: "next-alarm",
      user_id: socket.assigns.user.id
    )

    send_update(DrinkWaterWeb.AlarmSettingsComponent,
      id: "alarm-settings",
      user_id: socket.assigns.user.id
    )

    send_update(DrinkWaterWeb.WeeklySummaryComponent,
      id: "weekly-summary",
      user_id: socket.assigns.user.id,
      goal: goal,
      selected_date: socket.assigns.selected_date
    )

    {:noreply, assign(socket, goal: goal)}
  end

  # Edit intake from HistoryComponent
  @impl true
  def handle_info({:edit_intake, intake_id}, socket) do
    case HydrationTracking.get_water_intake(socket.assigns.user.id, intake_id) do
      {:ok, intake} ->
        {:noreply, assign(socket, editing_intake: intake)}

      {:error, :not_found, :water_intake} ->
        {:noreply, put_flash(socket, :error, gettext("Intake not found"))}
    end
  end

  @impl true
  def handle_info(:cancel_edit_intake, socket) do
    {:noreply, assign(socket, editing_intake: nil)}
  end

  # Flash from child components
  @impl true
  def handle_info({:flash, kind, message}, socket) do
    {:noreply, put_flash(socket, kind, message)}
  end

  @impl true
  def handle_info(_event, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("close-edit-modal", _params, socket) do
    {:noreply, assign(socket, editing_intake: nil)}
  end

  defp load_goal(user_id) do
    case UserManagement.get_alarm_settings_by_user(user_id) do
      {:ok, settings} -> settings.goal
      {:error, :not_found, :alarm_settings} -> @default_goal
    end
  end
end
