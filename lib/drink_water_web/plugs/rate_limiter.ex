defmodule DrinkWaterWeb.Plugs.RateLimiter do
  @moduledoc """
  Plug that enforces rate limiting per user on API endpoints.

  ## Options

    * `:key_prefix` - prefix for the rate limit key (required)
    * `:scale` - time window in milliseconds (default: 60_000 = 1 minute)
    * `:limit` - max requests per window (required)
    * `:key_params` - list of param names to try for user identification (default: ["user_id"])
  """
  import Plug.Conn
  alias DrinkWaterWeb.ProblemDetail

  @behaviour Plug

  @impl true
  def init(opts) do
    %{
      key_prefix: Keyword.fetch!(opts, :key_prefix),
      scale: Keyword.get(opts, :scale, :timer.minutes(1)),
      limit: Keyword.fetch!(opts, :limit),
      key_params: Keyword.get(opts, :key_params, ["user_id"])
    }
  end

  @impl true
  def call(conn, opts) do
    if Application.get_env(:drink_water, :rate_limiting_enabled, true) do
      do_rate_limit(conn, opts)
    else
      conn
    end
  end

  defp do_rate_limit(conn, %{
         key_prefix: prefix,
         scale: scale,
         limit: limit,
         key_params: key_params
       }) do
    user_id = extract_key(conn, key_params)
    key = "#{prefix}:#{user_id}"

    case DrinkWater.RateLimit.hit(key, scale, limit) do
      {:allow, _count} ->
        conn

      {:deny, retry_after_ms} ->
        retry_after = div(retry_after_ms, 1000) |> max(1)

        conn
        |> put_resp_content_type("application/problem+json")
        |> put_resp_header("retry-after", Integer.to_string(retry_after))
        |> send_resp(429, Jason.encode!(ProblemDetail.build(429, "Rate limit exceeded")))
        |> halt()
    end
  end

  defp extract_key(conn, key_params) do
    Enum.find_value(key_params, "anonymous", &conn.params[&1])
  end
end
