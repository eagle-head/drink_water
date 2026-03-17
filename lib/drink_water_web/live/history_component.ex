defmodule DrinkWaterWeb.HistoryComponent do
  use DrinkWaterWeb, :live_component

  alias DrinkWater.HydrationTracking

  @impl true
  def update(assigns, socket) do
    selected_date =
      assigns[:selected_date] || socket.assigns[:selected_date] || Date.utc_today()

    socket =
      socket
      |> assign(:user_id, assigns.user_id)
      |> assign(:selected_date, selected_date)
      |> load_intakes()

    {:ok, socket}
  end

  defp load_intakes(socket) do
    intakes =
      HydrationTracking.list_daily_intakes(
        socket.assigns.user_id,
        socket.assigns.selected_date
      )

    assign(socket, intakes: intakes)
  end

  @impl true
  def handle_event("nav-prev", _params, socket) do
    new_date = Date.add(socket.assigns.selected_date, -1)
    send(self(), {:select_date, new_date})
    {:noreply, socket}
  end

  @impl true
  def handle_event("nav-next", _params, socket) do
    new_date = Date.add(socket.assigns.selected_date, 1)
    send(self(), {:select_date, new_date})
    {:noreply, socket}
  end

  @impl true
  def handle_event("nav-today", _params, socket) do
    send(self(), {:select_date, Date.utc_today()})
    {:noreply, socket}
  end

  @impl true
  def handle_event("edit", %{"id" => id_str}, socket) do
    case Integer.parse(id_str) do
      {id, ""} -> send(self(), {:edit_intake, id})
      _ -> :noop
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", %{"id" => id_str}, socket) do
    case Integer.parse(id_str) do
      {id, ""} ->
        case HydrationTracking.delete_water_intake_by_id(socket.assigns.user_id, id) do
          {:ok, _} ->
            {:noreply, load_intakes(socket)}

          {:error, :not_found, :water_intake} ->
            send(self(), {:flash, :error, gettext("Intake already removed")})
            {:noreply, load_intakes(socket)}
        end

      _ ->
        {:noreply, socket}
    end
  end

  defp is_today?(date), do: date == Date.utc_today()

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :is_today, is_today?(assigns.selected_date))

    ~H"""
    <div>
      <div class="flex items-center justify-between mb-4">
        <%= if @is_today do %>
          <h2 class="card-title">{gettext("Today's History")}</h2>
        <% else %>
          <h2 class="card-title">
            {gettext("History")} — {Calendar.strftime(@selected_date, "%b %d, %Y")}
          </h2>
        <% end %>

        <div class="flex gap-1">
          <button
            phx-click="nav-prev"
            phx-target={@myself}
            class="btn btn-ghost btn-xs"
            title={gettext("Previous day")}
          >
            <.icon name="hero-chevron-left" class="w-4 h-4" />
          </button>

          <%= unless @is_today do %>
            <button
              phx-click="nav-today"
              phx-target={@myself}
              class="btn btn-ghost btn-xs"
            >
              {gettext("Today")}
            </button>
          <% end %>

          <button
            phx-click="nav-next"
            phx-target={@myself}
            class={"btn btn-ghost btn-xs #{if @is_today, do: "btn-disabled"}"}
            disabled={@is_today}
            title={gettext("Next day")}
          >
            <.icon name="hero-chevron-right" class="w-4 h-4" />
          </button>
        </div>
      </div>

      <%= if @intakes == [] do %>
        <p class="text-base-content/60">
          <%= if @is_today do %>
            {gettext("No water logged today")}
          <% else %>
            {gettext("No water logged on this day")}
          <% end %>
        </p>
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
                <td class="flex gap-1">
                  <button
                    phx-click="edit"
                    phx-value-id={intake.id}
                    phx-target={@myself}
                    class="btn btn-ghost btn-xs"
                  >
                    <.icon name="hero-pencil-square" class="w-4 h-4" />
                  </button>
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
