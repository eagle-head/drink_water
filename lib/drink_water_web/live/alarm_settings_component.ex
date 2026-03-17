defmodule DrinkWaterWeb.AlarmSettingsComponent do
  use DrinkWaterWeb, :live_component

  alias DrinkWater.UserManagement
  alias DrinkWater.UserManagement.AlarmSettings

  @impl true
  def update(assigns, socket) do
    alarm_settings = load_alarm_settings(assigns.user_id)

    # Preserve editing state across PubSub-triggered re-renders.
    editing = Map.get(socket.assigns, :editing, false)

    {:ok,
     socket
     |> assign(:user_id, assigns.user_id)
     |> assign(:alarm_settings, alarm_settings)
     |> assign(:editing, editing)
     |> assign_form(alarm_settings)}
  end

  defp load_alarm_settings(user_id) do
    case UserManagement.get_alarm_settings_by_user(user_id) do
      {:ok, settings} -> settings
      {:error, :not_found, :alarm_settings} -> nil
    end
  end

  defp assign_form(socket, nil) do
    changeset = AlarmSettings.changeset(%AlarmSettings{}, %{})
    assign(socket, form: to_form(changeset, as: :alarm_settings))
  end

  defp assign_form(socket, settings) do
    changeset = AlarmSettings.changeset(settings, %{})
    assign(socket, form: to_form(changeset, as: :alarm_settings))
  end

  @impl true
  def handle_event("edit-settings", _params, socket) do
    {:noreply, assign(socket, editing: true)}
  end

  @impl true
  def handle_event("cancel-edit", _params, socket) do
    {:noreply, assign(socket, editing: false)}
  end

  @impl true
  def handle_event("validate", %{"alarm_settings" => params}, socket) do
    changeset =
      (socket.assigns.alarm_settings || %AlarmSettings{})
      |> AlarmSettings.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: :alarm_settings))}
  end

  @impl true
  def handle_event("save", %{"alarm_settings" => params}, socket) do
    case UserManagement.update_alarm_settings(socket.assigns.alarm_settings, params) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> assign(alarm_settings: updated, editing: false)
         |> assign_form(updated)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: :alarm_settings))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h2 class="card-title mb-4">{gettext("Alarm Settings")}</h2>
      <%= if @alarm_settings == nil do %>
        <p class="label">{gettext("No alarm configured")}</p>
      <% else %>
        <%= unless @editing do %>
          <dl class="space-y-1 text-sm">
            <div class="flex justify-between">
              <dt class="label">{gettext("Goal")}</dt>
              <dd class="font-medium">{@alarm_settings.goal}ml</dd>
            </div>
            <div class="flex justify-between">
              <dt class="label">{gettext("Interval")}</dt>
              <dd class="font-medium">
                {@alarm_settings.interval_minutes} {gettext("min")}
              </dd>
            </div>
            <div class="flex justify-between">
              <dt class="label">{gettext("Hours")}</dt>
              <dd class="font-medium">
                {Calendar.strftime(@alarm_settings.daily_start_time, "%H:%M")} → {Calendar.strftime(
                  @alarm_settings.daily_end_time,
                  "%H:%M"
                )}
              </dd>
            </div>
          </dl>
          <button
            phx-click="edit-settings"
            phx-target={@myself}
            class="btn btn-soft btn-sm mt-4"
          >
            {gettext("Edit")}
          </button>
        <% else %>
          <.form
            for={@form}
            id="alarm-settings-form"
            phx-submit="save"
            phx-change="validate"
            phx-target={@myself}
            class="space-y-3"
          >
            <fieldset class="fieldset">
              <legend class="fieldset-legend">{gettext("Goal (ml)")}</legend>
              <input
                type="number"
                name={@form[:goal].name}
                value={@form[:goal].value}
                min="50"
                max="10000"
                class="input input-bordered"
              />
              <.error :for={error <- @form[:goal].errors}>{translate_error(error)}</.error>
            </fieldset>

            <fieldset class="fieldset">
              <legend class="fieldset-legend">{gettext("Interval (minutes)")}</legend>
              <input
                type="number"
                name={@form[:interval_minutes].name}
                value={@form[:interval_minutes].value}
                min="15"
                max="240"
                class="input input-bordered"
              />
              <.error :for={error <- @form[:interval_minutes].errors}>
                {translate_error(error)}
              </.error>
            </fieldset>

            <div class="grid grid-cols-2 gap-2">
              <fieldset class="fieldset">
                <legend class="fieldset-legend">{gettext("Start time")}</legend>
                <input
                  type="time"
                  name={@form[:daily_start_time].name}
                  value={@form[:daily_start_time].value}
                  class="input input-bordered"
                />
                <.error :for={error <- @form[:daily_start_time].errors}>
                  {translate_error(error)}
                </.error>
              </fieldset>
              <fieldset class="fieldset">
                <legend class="fieldset-legend">{gettext("End time")}</legend>
                <input
                  type="time"
                  name={@form[:daily_end_time].name}
                  value={@form[:daily_end_time].value}
                  class="input input-bordered"
                />
                <.error :for={error <- @form[:daily_end_time].errors}>
                  {translate_error(error)}
                </.error>
              </fieldset>
            </div>

            <div class="join">
              <button type="submit" class="join-item btn btn-primary btn-sm">
                {gettext("Save")}
              </button>
              <button
                type="button"
                phx-click="cancel-edit"
                phx-target={@myself}
                class="join-item btn btn-ghost btn-sm"
              >
                {gettext("Cancel")}
              </button>
            </div>
          </.form>
        <% end %>
      <% end %>
    </div>
    """
  end
end
