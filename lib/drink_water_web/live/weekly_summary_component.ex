defmodule DrinkWaterWeb.WeeklySummaryComponent do
  use DrinkWaterWeb, :live_component

  alias DrinkWater.HydrationTracking

  import DrinkWaterWeb.DashboardComponents, only: [weekly_chart: 1]

  @impl true
  def update(assigns, socket) do
    selected_date =
      assigns[:selected_date] || socket.assigns[:selected_date] || Date.utc_today()

    socket =
      socket
      |> assign(:user_id, assigns.user_id)
      |> assign(:goal, assigns.goal)
      |> assign(:selected_date, selected_date)
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
  def handle_event("select-day", %{"date" => date_str}, socket) do
    case Date.from_iso8601(date_str) do
      {:ok, date} -> send(self(), {:select_date, date})
      _ -> :noop
    end

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h2 class="card-title mb-4">{gettext("Weekly Summary")}</h2>
      <.weekly_chart days={@days} selected_date={@selected_date} target={@myself} />
    </div>
    """
  end
end
