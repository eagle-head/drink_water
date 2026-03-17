defmodule DrinkWaterWeb.ProgressComponent do
  use DrinkWaterWeb, :live_component

  alias DrinkWater.HydrationTracking

  import DrinkWaterWeb.DashboardComponents, only: [progress_ring: 1]

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(:user_id, assigns.user_id)
      |> assign(:goal, assigns.goal)
      |> load_progress()

    {:ok, socket}
  end

  defp load_progress(socket) do
    progress =
      HydrationTracking.daily_progress(
        socket.assigns.user_id,
        Date.utc_today(),
        socket.assigns.goal
      )

    assign(socket, progress)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
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
