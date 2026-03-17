defmodule DrinkWaterWeb.IntakeFormComponent do
  use DrinkWaterWeb, :live_component

  alias DrinkWater.HydrationTracking
  alias DrinkWater.HydrationTracking.WaterIntake

  @quick_volumes [150, 250, 500]

  @impl true
  def update(assigns, socket) do
    changeset = WaterIntake.changeset(%WaterIntake{}, %{})

    {:ok,
     socket
     |> assign(:user_id, assigns.user_id)
     |> assign(:quick_volumes, @quick_volumes)
     |> assign(:form, to_form(changeset, as: :intake))}
  end

  @impl true
  def handle_event("validate", %{"intake" => params}, socket) do
    changeset =
      %WaterIntake{}
      |> WaterIntake.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: :intake))}
  end

  @impl true
  def handle_event("save", %{"intake" => params}, socket) do
    attrs =
      params
      |> Map.put("date_time_utc", DateTime.utc_now())
      |> Map.put("volume_unit", "ml")

    case HydrationTracking.create_water_intake(socket.assigns.user_id, attrs) do
      {:ok, _intake} ->
        send(self(), {:flash, :info, gettext("Water logged!")})
        changeset = WaterIntake.changeset(%WaterIntake{}, %{})
        {:noreply, assign(socket, form: to_form(changeset, as: :intake))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: :intake))}
    end
  end

  @impl true
  def handle_event("quick-log", %{"volume" => volume_str}, socket) do
    case Integer.parse(volume_str) do
      {volume, ""} ->
        attrs = %{
          date_time_utc: DateTime.utc_now(),
          volume: volume,
          volume_unit: :ml
        }

        case HydrationTracking.create_water_intake(socket.assigns.user_id, attrs) do
          {:ok, _intake} ->
            send(self(), {:flash, :info, gettext("Water logged!")})
            {:noreply, socket}

          {:error, _changeset} ->
            send(self(), {:flash, :error, gettext("Failed to log water")})
            {:noreply, socket}
        end

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h2 class="card-title mb-4">{gettext("Log Water")}</h2>

      <div class="flex gap-2 mb-4">
        <button
          :for={volume <- @quick_volumes}
          phx-click="quick-log"
          phx-value-volume={volume}
          phx-target={@myself}
          class="btn btn-primary btn-sm"
        >
          {volume}ml
        </button>
      </div>

      <.form for={@form} id="intake-form" phx-submit="save" phx-change="validate" phx-target={@myself}>
        <div class="flex gap-2 items-end">
          <div class="form-control flex-1">
            <label class="label" for="intake-volume">{gettext("Custom volume (ml)")}</label>
            <input
              type="number"
              id="intake-volume"
              name={@form[:volume].name}
              value={@form[:volume].value}
              min="1"
              max="5000"
              class="input input-bordered w-full"
              placeholder={gettext("e.g. 330")}
            />
            <.error :for={error <- @form[:volume].errors}>{translate_error(error)}</.error>
          </div>
          <button type="submit" class="btn btn-primary">{gettext("Log")}</button>
        </div>
      </.form>
    </div>
    """
  end
end
