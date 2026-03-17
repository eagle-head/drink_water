defmodule DrinkWaterWeb.DashboardLive do
  use DrinkWaterWeb, :live_view

  alias DrinkWater.UserManagement

  # Hardcoded until auth is implemented (Step 10)
  @hardcoded_user_id 1

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(DrinkWater.PubSub, "user:#{@hardcoded_user_id}")
    end

    {:ok, assign(socket, page_title: gettext("Hydration Dashboard"))}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    case UserManagement.get_user(@hardcoded_user_id) do
      {:ok, user} ->
        {:noreply, assign(socket, user: user)}

      {:error, :not_found, :user} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("User not found"))
         |> redirect(to: ~p"/")}
    end
  end

  @impl true
  def handle_info(_event, socket) do
    # PubSub dispatch — will be expanded in later sub-steps
    {:noreply, socket}
  end
end
