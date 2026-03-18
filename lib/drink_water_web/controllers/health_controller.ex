defmodule DrinkWaterWeb.HealthController do
  use DrinkWaterWeb, :controller

  def index(conn, _params) do
    db_status = check_db()
    status_code = if db_status == :ok, do: 200, else: 503
    overall = if db_status == :ok, do: :healthy, else: :degraded

    conn
    |> put_status(status_code)
    |> json(%{
      status: overall,
      checks: %{
        database: db_status,
        beam: %{
          uptime_seconds: :erlang.statistics(:wall_clock) |> elem(0) |> div(1000),
          memory_mb: :erlang.memory(:total) |> div(1_048_576),
          process_count: :erlang.system_info(:process_count),
          schedulers: :erlang.system_info(:schedulers_online)
        }
      }
    })
  end

  defp check_db do
    case Ecto.Adapters.SQL.query(DrinkWater.Repo, "SELECT 1", []) do
      {:ok, _} -> :ok
      {:error, _} -> :error
    end
  end
end
