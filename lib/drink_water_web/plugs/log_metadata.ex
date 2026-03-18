defmodule DrinkWaterWeb.Plugs.LogMetadata do
  @moduledoc "Sets Logger metadata from route params for structured logging."

  @behaviour Plug
  require Logger

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    user_id = conn.params["user_id"] || conn.params["id"]
    if user_id, do: Logger.metadata(user_id: user_id)
    conn
  end
end
