defmodule DrinkWaterWeb.WeeklySummaryComponent do
  use DrinkWaterWeb, :live_component

  alias DrinkWater.HydrationTracking

  import DrinkWaterWeb.DashboardComponents, only: [weekly_chart: 1]

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(:user_id, assigns.user_id)
      |> assign(:goal, assigns.goal)
      |> load_summary()

    {:ok, socket}
  end

  defp load_summary(socket) do
    days =
      HydrationTracking.weekly_summary(
        socket.assigns.user_id,
        Date.utc_today(),
        socket.assigns.goal
      )

    assign(socket, days: days)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h2 class="card-title mb-4">{gettext("Weekly Summary")}</h2>
      <.weekly_chart days={@days} />
    </div>
    """
  end
end
