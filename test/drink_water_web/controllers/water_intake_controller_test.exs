defmodule DrinkWaterWeb.WaterIntakeControllerTest do
  use DrinkWaterWeb.ConnCase

  import DrinkWater.UserManagementFixtures
  import DrinkWater.HydrationTrackingFixtures

  @create_attrs %{
    date_time_utc: ~U[2026-03-14 10:00:00Z],
    volume: 250,
    volume_unit: :ml
  }
  @update_attrs %{
    date_time_utc: ~U[2026-03-14 14:00:00Z],
    volume: 500,
    volume_unit: :ml
  }
  @invalid_attrs %{
    date_time_utc: nil,
    volume: nil,
    volume_unit: nil
  }

  setup %{conn: conn} do
    user = user_fixture()
    {:ok, conn: put_req_header(conn, "accept", "application/json"), user: user}
  end

  @date_range %{
    "start_date" => "2026-03-01T00:00:00Z",
    "end_date" => "2026-03-31T23:59:59Z"
  }

  describe "index" do
    test "lists water intakes with required date range", %{conn: conn, user: user} do
      water_intake_fixture(user.id)
      conn = get(conn, ~p"/api/users/#{user.id}/water_intakes", @date_range)
      response = json_response(conn, 200)
      assert length(response["data"]) == 1
      assert is_nil(response["next_cursor"])
    end

    test "returns 422 in RFC 7807 format when required date params are missing", %{
      conn: conn,
      user: user
    } do
      conn = get(conn, ~p"/api/users/#{user.id}/water_intakes")
      response = json_response(conn, 422)
      assert response["type"] == "https://www.drinkwater.com.br/validation-error"
      assert response["title"] == "Unprocessable Content"
      assert response["status"] == 422

      assert response["detail"] ==
               "One or more fields are invalid. Please correct them and try again."

      assert response["instance"] == "/api/users/#{user.id}/water_intakes"
      assert response["errors"] != %{}
    end

    test "returns paginated results with next_cursor", %{conn: conn, user: user} do
      for i <- 1..3 do
        water_intake_fixture(user.id, %{
          date_time_utc: DateTime.add(~U[2026-03-10 10:00:00Z], i * 3600, :second)
        })
      end

      params = Map.merge(@date_range, %{"size" => "2"})
      conn = get(conn, ~p"/api/users/#{user.id}/water_intakes", params)
      response = json_response(conn, 200)
      assert length(response["data"]) == 2
      assert response["next_cursor"] != nil

      conn =
        get(
          conn,
          ~p"/api/users/#{user.id}/water_intakes",
          Map.put(params, "cursor", response["next_cursor"])
        )

      response2 = json_response(conn, 200)
      assert length(response2["data"]) == 1
      assert is_nil(response2["next_cursor"])
    end

    test "returns 400 in RFC 7807 format for invalid cursor", %{conn: conn, user: user} do
      params = Map.merge(@date_range, %{"cursor" => "invalid-cursor"})
      conn = get(conn, ~p"/api/users/#{user.id}/water_intakes", params)
      assert {"content-type", "application/problem+json; charset=utf-8"} in conn.resp_headers
      response = json_response(conn, 400)
      assert response["type"] == "https://www.drinkwater.com.br/invalid-argument"
      assert response["title"] == "Bad Request"
      assert response["status"] == 400
      assert response["detail"] == "An invalid argument was provided."
      assert response["instance"] == "/api/users/#{user.id}/water_intakes"
    end

    test "sorts by volume ascending", %{conn: conn, user: user} do
      water_intake_fixture(user.id, %{date_time_utc: ~U[2026-03-14 10:00:00Z], volume: 500})
      water_intake_fixture(user.id, %{date_time_utc: ~U[2026-03-14 11:00:00Z], volume: 100})

      params = Map.merge(@date_range, %{"sort_field" => "volume", "sort_direction" => "asc"})
      conn = get(conn, ~p"/api/users/#{user.id}/water_intakes", params)
      response = json_response(conn, 200)
      volumes = Enum.map(response["data"], & &1["volume"])
      assert volumes == [100, 500]
    end

    test "returns 422 for invalid sort_field", %{conn: conn, user: user} do
      params = Map.merge(@date_range, %{"sort_field" => "email"})
      conn = get(conn, ~p"/api/users/#{user.id}/water_intakes", params)
      response = json_response(conn, 422)
      assert response["type"] == "https://www.drinkwater.com.br/validation-error"
      assert response["errors"]["sort_field"]
    end

    test "returns 404 in RFC 7807 format for nonexistent user", %{conn: conn} do
      conn = get(conn, ~p"/api/users/0/water_intakes", @date_range)
      response = json_response(conn, 404)
      assert response["type"] == "https://www.drinkwater.com.br/user-not-found"
      assert response["title"] == "Not Found"
      assert response["status"] == 404
      assert response["detail"] == "The requested user account was not found."
      assert response["instance"] == "/api/users/0/water_intakes"
    end
  end

  describe "create water_intake" do
    test "renders water_intake when data is valid", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/api/users/#{user.id}/water_intakes", water_intake: @create_attrs)

      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"/api/users/#{user.id}/water_intakes/#{id}")

      assert %{
               "id" => ^id,
               "date_time_utc" => "2026-03-14T10:00:00Z",
               "volume" => 250,
               "volume_unit" => "ml"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors in RFC 7807 format when data is invalid", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/api/users/#{user.id}/water_intakes", water_intake: @invalid_attrs)

      response = json_response(conn, 422)
      assert response["type"] == "https://www.drinkwater.com.br/validation-error"
      assert response["title"] == "Unprocessable Content"
      assert response["status"] == 422

      assert response["detail"] ==
               "One or more fields are invalid. Please correct them and try again."

      assert response["instance"] == "/api/users/#{user.id}/water_intakes"
      assert response["errors"] != %{}
    end

    test "returns 404 in RFC 7807 format for nonexistent user", %{conn: conn} do
      conn = post(conn, ~p"/api/users/0/water_intakes", water_intake: @create_attrs)
      response = json_response(conn, 404)
      assert response["type"] == "https://www.drinkwater.com.br/user-not-found"
      assert response["title"] == "Not Found"
      assert response["status"] == 404
      assert response["detail"] == "The requested user account was not found."
      assert response["instance"] == "/api/users/0/water_intakes"
    end

    test "returns 409 when creating water intake with duplicate datetime", %{
      conn: conn,
      user: user
    } do
      post(conn, ~p"/api/users/#{user.id}/water_intakes", water_intake: @create_attrs)
      conn = post(conn, ~p"/api/users/#{user.id}/water_intakes", water_intake: @create_attrs)
      assert {"content-type", "application/problem+json; charset=utf-8"} in conn.resp_headers
      response = json_response(conn, 409)
      assert response["type"] == "https://www.drinkwater.com.br/waterintake-duplicate-datetime"
      assert response["title"] == "Conflict"
      assert response["status"] == 409

      assert response["detail"] ==
               "A water intake record already exists for the specified date and time."

      assert response["instance"] == "/api/users/#{user.id}/water_intakes"
    end
  end

  describe "show water_intake" do
    test "returns water_intake", %{conn: conn, user: user} do
      water_intake = water_intake_fixture(user.id)
      conn = get(conn, ~p"/api/users/#{user.id}/water_intakes/#{water_intake.id}")

      assert %{
               "id" => _,
               "volume" => 250,
               "volume_unit" => "ml"
             } = json_response(conn, 200)["data"]
    end

    test "returns 404 in RFC 7807 format for nonexistent intake", %{conn: conn, user: user} do
      conn = get(conn, ~p"/api/users/#{user.id}/water_intakes/0")
      assert {"content-type", "application/problem+json; charset=utf-8"} in conn.resp_headers
      response = json_response(conn, 404)
      assert response["type"] == "https://www.drinkwater.com.br/waterintake-not-found"
      assert response["title"] == "Not Found"
      assert response["status"] == 404
      assert response["detail"] == "The requested water intake record was not found."
      assert response["instance"] == "/api/users/#{user.id}/water_intakes/0"
    end

    test "returns 404 in RFC 7807 format for nonexistent user", %{conn: conn} do
      conn = get(conn, ~p"/api/users/0/water_intakes/0")
      response = json_response(conn, 404)
      assert response["type"] == "https://www.drinkwater.com.br/user-not-found"
      assert response["title"] == "Not Found"
      assert response["status"] == 404
      assert response["detail"] == "The requested user account was not found."
      assert response["instance"] == "/api/users/0/water_intakes/0"
    end
  end

  describe "update water_intake" do
    test "renders water_intake when data is valid", %{conn: conn, user: user} do
      water_intake = water_intake_fixture(user.id)

      conn =
        put(conn, ~p"/api/users/#{user.id}/water_intakes/#{water_intake.id}",
          water_intake: @update_attrs
        )

      assert %{
               "volume" => 500,
               "date_time_utc" => "2026-03-14T14:00:00Z"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors in RFC 7807 format when data is invalid", %{conn: conn, user: user} do
      water_intake = water_intake_fixture(user.id)

      conn =
        put(conn, ~p"/api/users/#{user.id}/water_intakes/#{water_intake.id}",
          water_intake: @invalid_attrs
        )

      response = json_response(conn, 422)
      assert response["type"] == "https://www.drinkwater.com.br/validation-error"
      assert response["title"] == "Unprocessable Content"
      assert response["status"] == 422

      assert response["detail"] ==
               "One or more fields are invalid. Please correct them and try again."

      assert response["instance"] == "/api/users/#{user.id}/water_intakes/#{water_intake.id}"
      assert response["errors"] != %{}
    end
  end

  describe "delete water_intake" do
    test "deletes water_intake", %{conn: conn, user: user} do
      water_intake = water_intake_fixture(user.id)

      conn = delete(conn, ~p"/api/users/#{user.id}/water_intakes/#{water_intake.id}")
      assert response(conn, 204)

      conn = get(conn, ~p"/api/users/#{user.id}/water_intakes/#{water_intake.id}")
      response = json_response(conn, 404)
      assert response["type"] == "https://www.drinkwater.com.br/waterintake-not-found"
      assert response["title"] == "Not Found"
      assert response["status"] == 404
      assert response["detail"] == "The requested water intake record was not found."
      assert response["instance"] == "/api/users/#{user.id}/water_intakes/#{water_intake.id}"
    end
  end
end
