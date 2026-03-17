defmodule DrinkWaterWeb.ProgressComponent do
  use DrinkWaterWeb, :live_component

  alias DrinkWater.HydrationTracking

  import DrinkWaterWeb.DashboardComponents, only: [progress_ring: 1]

  @impl true
  def update(assigns, socket) do
    selected_date =
      assigns[:selected_date] || socket.assigns[:selected_date] || Date.utc_today()

    socket =
      socket
      |> assign(:user_id, assigns.user_id)
      |> assign(:goal, assigns.goal)
      |> assign(:selected_date, selected_date)
      |> load_progress()

    {:ok, socket}
  end

  defp load_progress(socket) do
    progress =
      HydrationTracking.daily_progress(
        socket.assigns.user_id,
        socket.assigns.selected_date,
        socket.assigns.goal
      )

    assign(socket, progress)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <%= if @selected_date == Date.utc_today() do %>
        <h2 class="card-title mb-4">{gettext("Daily Progress")}</h2>
      <% else %>
        <h2 class="card-title mb-4">
          {gettext("Progress")} — {Calendar.strftime(@selected_date, "%b %d, %Y")}
        </h2>
      <% end %>
      <.progress_ring
        percentage={@percentage}
        total_ml={@total_ml}
        goal={@goal}
        intake_count={@intake_count}
      />
    </div>
    """
  end
end
