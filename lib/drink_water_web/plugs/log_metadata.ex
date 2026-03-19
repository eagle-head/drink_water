defmodule DrinkWaterWeb.Plugs.LogMetadata do
  @moduledoc "Sets Logger metadata from route params for structured logging."

  @behaviour Plug
  require Logger

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    case conn.params["user_id"] || conn.params["id"] do
      nil -> :ok
      user_id -> Logger.metadata(user_id: user_id)
    end

    conn
  end
end
