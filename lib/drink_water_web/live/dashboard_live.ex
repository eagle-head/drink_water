defmodule DrinkWaterWeb.DashboardLive do
  use DrinkWaterWeb, :live_view

  alias DrinkWater.UserManagement

  # Hardcoded until auth is implemented (Step 10)
  @hardcoded_user_id 1
  @default_goal 2000

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(DrinkWater.PubSub, "user:#{@hardcoded_user_id}")
    end

    {:ok, assign(socket, page_title: gettext("Hydration Dashboard"))}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    with {:ok, user} <- UserManagement.get_user(@hardcoded_user_id) do
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
  def handle_info(:intake_created, socket) do
    send_update(DrinkWaterWeb.ProgressComponent,
      id: "progress",
      user_id: socket.assigns.user.id,
      goal: socket.assigns.goal
    )

    send_update(DrinkWaterWeb.HistoryComponent,
      id: "history",
      user_id: socket.assigns.user.id
    )

    {:noreply, socket}
  end

  def handle_info(:intake_deleted, socket) do
    send_update(DrinkWaterWeb.ProgressComponent,
      id: "progress",
      user_id: socket.assigns.user.id,
      goal: socket.assigns.goal
    )

    send_update(DrinkWaterWeb.HistoryComponent,
      id: "history",
      user_id: socket.assigns.user.id
    )

    {:noreply, socket}
  end

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
