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

  describe "index" do
    test "lists all water intakes for a user", %{conn: conn, user: user} do
      conn = get(conn, ~p"/api/users/#{user.id}/water_intakes")
      assert json_response(conn, 200)["data"] == []
    end

    test "returns 404 for nonexistent user", %{conn: conn} do
      conn = get(conn, ~p"/api/users/0/water_intakes")
      assert json_response(conn, 404)
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

    test "renders errors when data is invalid", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/api/users/#{user.id}/water_intakes", water_intake: @invalid_attrs)

      assert json_response(conn, 422)["errors"] != %{}
    end

    test "returns 404 for nonexistent user", %{conn: conn} do
      conn = post(conn, ~p"/api/users/0/water_intakes", water_intake: @create_attrs)
      assert json_response(conn, 404)
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

    test "returns 404 for nonexistent intake", %{conn: conn, user: user} do
      conn = get(conn, ~p"/api/users/#{user.id}/water_intakes/0")
      assert json_response(conn, 404)
    end

    test "returns 404 for nonexistent user", %{conn: conn} do
      conn = get(conn, ~p"/api/users/0/water_intakes/0")
      assert json_response(conn, 404)
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

    test "renders errors when data is invalid", %{conn: conn, user: user} do
      water_intake = water_intake_fixture(user.id)

      conn =
        put(conn, ~p"/api/users/#{user.id}/water_intakes/#{water_intake.id}",
          water_intake: @invalid_attrs
        )

      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete water_intake" do
    test "deletes water_intake", %{conn: conn, user: user} do
      water_intake = water_intake_fixture(user.id)

      conn = delete(conn, ~p"/api/users/#{user.id}/water_intakes/#{water_intake.id}")
      assert response(conn, 204)

      conn = get(conn, ~p"/api/users/#{user.id}/water_intakes/#{water_intake.id}")
      assert json_response(conn, 404)
    end
  end
end
