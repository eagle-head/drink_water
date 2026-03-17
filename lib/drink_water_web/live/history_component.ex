defmodule DrinkWaterWeb.HistoryComponent do
  use DrinkWaterWeb, :live_component

  alias DrinkWater.HydrationTracking

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(:user_id, assigns.user_id)
      |> load_intakes()

    {:ok, socket}
  end

  defp load_intakes(socket) do
    intakes = HydrationTracking.list_daily_intakes(socket.assigns.user_id, Date.utc_today())
    assign(socket, intakes: intakes)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    id = String.to_integer(id)

    case HydrationTracking.delete_water_intake_by_id(socket.assigns.user_id, id) do
      {:ok, _} ->
        {:noreply, load_intakes(socket)}

      {:error, :not_found, :water_intake} ->
        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h2 class="card-title mb-4">{gettext("Today's History")}</h2>
      <%= if @intakes == [] do %>
        <p class="text-base-content/60">{gettext("No water logged today")}</p>
      <% else %>
        <div class="overflow-x-auto">
          <table class="table">
            <thead>
              <tr>
                <th>{gettext("Time")}</th>
                <th>{gettext("Volume")}</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr :for={intake <- @intakes} data-intake-id={intake.id}>
                <td>{Calendar.strftime(intake.date_time_utc, "%H:%M")}</td>
                <td>{intake.volume}ml</td>
                <td>
                  <button
                    phx-click="delete"
                    phx-value-id={intake.id}
                    phx-target={@myself}
                    class="btn btn-ghost btn-xs text-error"
                  >
                    <.icon name="hero-x-mark" class="w-4 h-4" />
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      <% end %>
    </div>
    """
  end
end
