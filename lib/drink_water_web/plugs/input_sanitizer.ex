defmodule DrinkWaterWeb.Plugs.InputSanitizer do
  @moduledoc """
  Plug that sanitizes all string input params at the boundary.

  - Removes null bytes (\\0) that crash PostgreSQL
  - Trims leading/trailing whitespace
  - Operates recursively on nested maps and lists
  - Skips structs (DateTime, Date, Time, Plug.Upload, etc.)
  """
  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    %{
      conn
      | params: sanitize(conn.params),
        body_params: sanitize_if_fetched(conn.body_params),
        query_params: sanitize_if_fetched(conn.query_params),
        path_params: sanitize(conn.path_params)
    }
  end

  defp sanitize_if_fetched(%Plug.Conn.Unfetched{} = unfetched), do: unfetched
  defp sanitize_if_fetched(params), do: sanitize(params)

  defp sanitize(value) when is_binary(value) do
    value
    |> String.replace("\0", "")
    |> String.trim()
  end

  defp sanitize(%_{} = struct), do: struct

  defp sanitize(value) when is_map(value) do
    Map.new(value, fn {k, v} -> {k, sanitize(v)} end)
  end

  defp sanitize(value) when is_list(value) do
    Enum.map(value, &sanitize/1)
  end

  defp sanitize(value), do: value
end
