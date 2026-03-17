defmodule DrinkWaterWeb.ProgressComponent do
  use DrinkWaterWeb, :live_component

  alias DrinkWater.HydrationTracking

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
      <%= if @selected_date != Date.utc_today() do %>
        <h2 class="card-title mb-2">
          {gettext("Progress")} — {Calendar.strftime(@selected_date, "%b %d, %Y")}
        </h2>
      <% end %>
      <div class="stat place-items-center">
        <div class="stat-figure text-primary">
          <div
            class="radial-progress text-primary"
            style={"--value:#{@percentage}; --size:5rem; --thickness:0.5rem;"}
            role="progressbar"
          >
            {@percentage |> Float.round(0) |> trunc()}%
          </div>
        </div>
        <div class="stat-value">{@total_ml}ml</div>
        <div class="stat-desc">
          {gettext("Goal")}: {@goal}ml — {ngettext("1 intake", "%{count} intakes", @intake_count)}
        </div>
      </div>
    </div>
    """
  end
end
