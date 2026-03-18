defmodule DrinkWaterWeb.HealthControllerTest do
  use DrinkWaterWeb.ConnCase

  describe "GET /api/health" do
    test "returns 200 with healthy status when DB is reachable", %{conn: conn} do
      conn = get(conn, ~p"/api/health")
      response = json_response(conn, 200)

      assert response["status"] == "healthy"
      assert response["checks"]["database"] == "ok"

      beam = response["checks"]["beam"]
      assert is_integer(beam["uptime_seconds"])
      assert is_integer(beam["memory_mb"])
      assert is_integer(beam["process_count"])
      assert is_integer(beam["schedulers"])
      assert beam["schedulers"] > 0
    end
  end
end
