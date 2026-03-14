defmodule DrinkWaterWeb.AlarmSettingsControllerTest do
  use DrinkWaterWeb.ConnCase

  import DrinkWater.UserManagementFixtures

  @create_attrs %{
    goal: 2000,
    interval_minutes: 60,
    daily_start_time: ~T[08:00:00],
    daily_end_time: ~T[20:00:00]
  }
  @update_attrs %{
    goal: 3000,
    interval_minutes: 30,
    daily_start_time: ~T[07:00:00],
    daily_end_time: ~T[21:00:00]
  }
  @invalid_attrs %{
    goal: nil,
    interval_minutes: nil,
    daily_start_time: nil,
    daily_end_time: nil
  }

  setup %{conn: conn} do
    user = user_fixture()
    {:ok, conn: put_req_header(conn, "accept", "application/json"), user: user}
  end

  describe "create alarm_settings" do
    test "renders alarm_settings when data is valid", %{conn: conn, user: user} do
      conn = post(conn, ~p"/api/users/#{user.id}/alarm_settings", alarm_settings: @create_attrs)
      assert %{"id" => _id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"/api/users/#{user.id}/alarm_settings")

      assert %{
               "goal" => 2000,
               "interval_minutes" => 60,
               "daily_start_time" => "08:00:00",
               "daily_end_time" => "20:00:00"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, user: user} do
      conn = post(conn, ~p"/api/users/#{user.id}/alarm_settings", alarm_settings: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end

    test "returns 404 for nonexistent user", %{conn: conn} do
      conn = post(conn, ~p"/api/users/0/alarm_settings", alarm_settings: @create_attrs)
      assert json_response(conn, 404)
    end
  end

  describe "show alarm_settings" do
    test "returns alarm_settings for user", %{conn: conn, user: user} do
      alarm_settings_fixture(user)
      conn = get(conn, ~p"/api/users/#{user.id}/alarm_settings")

      assert %{
               "goal" => 2000,
               "interval_minutes" => 60,
               "daily_start_time" => "08:00:00",
               "daily_end_time" => "20:00:00"
             } = json_response(conn, 200)["data"]
    end

    test "returns 404 when user has no settings", %{conn: conn, user: user} do
      conn = get(conn, ~p"/api/users/#{user.id}/alarm_settings")
      assert json_response(conn, 404)
    end

    test "returns 404 for nonexistent user", %{conn: conn} do
      conn = get(conn, ~p"/api/users/0/alarm_settings")
      assert json_response(conn, 404)
    end
  end

  describe "update alarm_settings" do
    test "renders alarm_settings when data is valid", %{conn: conn, user: user} do
      alarm_settings_fixture(user)

      conn =
        put(conn, ~p"/api/users/#{user.id}/alarm_settings", alarm_settings: @update_attrs)

      assert %{
               "goal" => 3000,
               "interval_minutes" => 30,
               "daily_start_time" => "07:00:00",
               "daily_end_time" => "21:00:00"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, user: user} do
      alarm_settings_fixture(user)

      conn =
        put(conn, ~p"/api/users/#{user.id}/alarm_settings", alarm_settings: @invalid_attrs)

      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete alarm_settings" do
    test "deletes alarm_settings", %{conn: conn, user: user} do
      alarm_settings_fixture(user)

      conn = delete(conn, ~p"/api/users/#{user.id}/alarm_settings")
      assert response(conn, 204)

      conn = get(conn, ~p"/api/users/#{user.id}/alarm_settings")
      assert json_response(conn, 404)
    end
  end
end
