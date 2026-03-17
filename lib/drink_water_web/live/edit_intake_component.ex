defmodule DrinkWaterWeb.EditIntakeComponent do
  use DrinkWaterWeb, :live_component

  alias DrinkWater.HydrationTracking
  alias DrinkWater.HydrationTracking.WaterIntake

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, :intake, assigns.intake)

    socket =
      if socket.assigns[:form] do
        socket
      else
        changeset = WaterIntake.changeset(assigns.intake, %{})
        assign(socket, :form, to_form(changeset, as: :intake))
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"intake" => params}, socket) do
    changeset =
      socket.assigns.intake
      |> WaterIntake.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: :intake))}
  end

  @impl true
  def handle_event("save", %{"intake" => params}, socket) do
    case HydrationTracking.update_water_intake(socket.assigns.intake, params) do
      {:ok, _updated} ->
        send(self(), :cancel_edit_intake)
        send(self(), {:flash, :info, gettext("Intake updated!")})
        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: :intake))}
    end
  end

  @impl true
  def handle_event("cancel", _params, socket) do
    send(self(), :cancel_edit_intake)
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h3 class="text-lg font-bold mb-4">{gettext("Edit Intake")}</h3>
      <.form
        for={@form}
        id="edit-intake-form"
        phx-submit="save"
        phx-change="validate"
        phx-target={@myself}
        class="space-y-3"
      >
        <div class="form-control">
          <label class="label">{gettext("Volume (ml)")}</label>
          <input
            type="number"
            name={@form[:volume].name}
            value={@form[:volume].value}
            min="1"
            max="5000"
            class="input input-bordered"
          />
          <.error :for={error <- @form[:volume].errors}>{translate_error(error)}</.error>
        </div>

        <div class="form-control">
          <label class="label">{gettext("Date/Time (UTC)")}</label>
          <input
            type="datetime-local"
            name={@form[:date_time_utc].name}
            value={format_datetime(@form[:date_time_utc].value)}
            class="input input-bordered"
          />
          <.error :for={error <- @form[:date_time_utc].errors}>{translate_error(error)}</.error>
        </div>

        <div class="flex gap-2">
          <button type="submit" class="btn btn-primary btn-sm">
            {gettext("Save")}
          </button>
          <button
            type="button"
            phx-click="cancel"
            phx-target={@myself}
            class="btn btn-ghost btn-sm"
          >
            {gettext("Cancel")}
          </button>
        </div>
      </.form>
    </div>
    """
  end

  defp format_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%dT%H:%M:%S")
  end

  defp format_datetime(value) when is_binary(value), do: value
  defp format_datetime(_), do: ""
end
