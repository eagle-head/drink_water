defmodule DrinkWaterWeb.LiveRateLimit do
  @moduledoc """
  Server-side rate limiting for LiveView events.
  Reuses the Hammer ETS backend from DrinkWater.RateLimit.

  ## Usage in a LiveComponent handle_event:

      case LiveRateLimit.check(socket, "write", 30) do
        {:allow, _count} ->
          # proceed with the action
          {:noreply, socket}

        {:deny, socket} ->
          # socket already has flash set
          {:noreply, socket}
      end

  Key format: "lv:{user_id}:{action_group}"
  Default window: 60 seconds.
  """

  use Gettext, backend: DrinkWaterWeb.Gettext

  @default_scale :timer.minutes(1)

  @doc """
  Check rate limit for the current user and action group.

  Returns `{:allow, count}` or `{:deny, socket}` with a flash message.
  """
  def check(socket, action_group, limit, opts \\ []) do
    scale = Keyword.get(opts, :scale, @default_scale)
    user_id = socket.assigns[:user_id] || "anonymous"
    key = "lv:#{user_id}:#{action_group}"

    if enabled?() do
      case DrinkWater.RateLimit.hit(key, scale, limit) do
        {:allow, count} ->
          {:allow, count}

        {:deny, _retry_after_ms} ->
          socket =
            Phoenix.LiveView.put_flash(
              socket,
              :error,
              gettext("Too many requests. Please slow down.")
            )

          {:deny, socket}
      end
    else
      {:allow, 0}
    end
  end

  defp enabled?, do: Application.get_env(:drink_water, :rate_limiting_enabled, true)
end
