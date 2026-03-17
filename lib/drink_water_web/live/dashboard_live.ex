defmodule DrinkWaterWeb.DashboardLive do
  use DrinkWaterWeb, :live_view

  alias DrinkWater.UserManagement

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
       |> assign(user: user, goal: goal)}
    else
      {:error, :not_found, :user} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("User not found"))
         |> redirect(to: ~p"/")}
    end
  end

  @impl true
  def handle_info(event, socket) when event in [:intake_created, :intake_deleted] do
    send_update(DrinkWaterWeb.ProgressComponent,
      id: "progress",
      user_id: socket.assigns.user.id,
      goal: socket.assigns.goal
    )

    send_update(DrinkWaterWeb.HistoryComponent,
      id: "history",
      user_id: socket.assigns.user.id
    )

    send_update(DrinkWaterWeb.WeeklySummaryComponent,
      id: "weekly-summary",
      user_id: socket.assigns.user.id,
      goal: socket.assigns.goal
    )

    {:noreply, socket}
  end

  @impl true
  def handle_info(:alarm_settings_updated, socket) do
    goal = load_goal(socket.assigns.user.id)

    send_update(DrinkWaterWeb.ProgressComponent,
      id: "progress",
      user_id: socket.assigns.user.id,
      goal: goal
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
      goal: goal
    )

    {:noreply, assign(socket, goal: goal)}
  end

  @impl true
  def handle_info({:flash, kind, message}, socket) do
    {:noreply, put_flash(socket, kind, message)}
  end

  @impl true
  def handle_info(_event, socket) do
    {:noreply, socket}
  end

  defp load_goal(user_id) do
    case UserManagement.get_alarm_settings_by_user(user_id) do
      {:ok, settings} -> settings.goal
      {:error, :not_found, :alarm_settings} -> @default_goal
    end
  end
end
