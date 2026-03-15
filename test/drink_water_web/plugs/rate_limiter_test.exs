defmodule DrinkWaterWeb.Plugs.RateLimiterTest do
  use DrinkWaterWeb.ConnCase, async: false

  import DrinkWater.UserManagementFixtures

  setup %{conn: conn} do
    Application.put_env(:drink_water, :rate_limiting_enabled, true)

    on_exit(fn ->
      Application.put_env(:drink_water, :rate_limiting_enabled, false)
    end)

    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "user API rate limiting" do
    test "allows requests within limit", %{conn: conn} do
      user = user_fixture()
      conn = get(conn, ~p"/api/users/#{user.id}")
      assert json_response(conn, 200)
    end

    test "returns 429 with RFC 7807 and Retry-After when limit exceeded", %{conn: conn} do
      user = user_fixture()

      for _ <- 1..30 do
        conn = get(conn, ~p"/api/users/#{user.id}")
        assert json_response(conn, 200)
      end

      conn = get(conn, ~p"/api/users/#{user.id}")
      response = json_response(conn, 429)
      assert response["type"] == "https://www.drinkwater.com.br/rate-limit-exceeded"
      assert response["title"] == "Too Many Requests"
      assert response["status"] == 429
      assert response["detail"] == "Too many requests. Please wait before trying again."
      assert response["instance"] != nil
      assert {"retry-after", _} = List.keyfind(conn.resp_headers, "retry-after", 0)
      assert {"content-type", "application/problem+json; charset=utf-8"} in conn.resp_headers
    end
  end

  describe "per-user isolation" do
    test "rate limit is per user, not global", %{conn: conn} do
      user1 = user_fixture()
      user2 = user_fixture()

      for _ <- 1..30 do
        get(conn, ~p"/api/users/#{user1.id}")
      end

      conn = get(conn, ~p"/api/users/#{user1.id}")
      assert json_response(conn, 429)

      conn = get(conn, ~p"/api/users/#{user2.id}")
      assert json_response(conn, 200)
    end
  end

  describe "separate limits per endpoint group" do
    test "water intake API has independent limit from user API", %{conn: conn} do
      user = user_fixture()

      for _ <- 1..30 do
        get(conn, ~p"/api/users/#{user.id}")
      end

      conn = get(conn, ~p"/api/users/#{user.id}")
      assert json_response(conn, 429)

      conn =
        get(
          conn,
          ~p"/api/users/#{user.id}/water_intakes",
          %{"start_date" => "2026-03-01T00:00:00Z", "end_date" => "2026-03-31T23:59:59Z"}
        )

      assert conn.status != 429
    end
  end
end
