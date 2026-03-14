defmodule DrinkWaterWeb.UserControllerTest do
  use DrinkWaterWeb.ConnCase

  import DrinkWater.UserManagementFixtures
  alias DrinkWater.UserManagement.User

  @create_attrs %{
    email: "some email",
    first_name: "some first_name",
    last_name: "some last_name",
    birth_date: ~D[2026-03-13],
    biological_sex: 42,
    weight: "120.5",
    weight_unit: 42,
    height: "120.5",
    height_unit: 42
  }
  @update_attrs %{
    email: "some updated email",
    first_name: "some updated first_name",
    last_name: "some updated last_name",
    birth_date: ~D[2026-03-14],
    biological_sex: 43,
    weight: "456.7",
    weight_unit: 43,
    height: "456.7",
    height_unit: 43
  }
  @invalid_attrs %{
    email: nil,
    first_name: nil,
    last_name: nil,
    birth_date: nil,
    biological_sex: nil,
    weight: nil,
    weight_unit: nil,
    height: nil,
    height_unit: nil
  }

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all users", %{conn: conn} do
      conn = get(conn, ~p"/api/users")
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create user" do
    test "renders user when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/api/users", user: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"/api/users/#{id}")

      assert %{
               "id" => ^id,
               "biological_sex" => 42,
               "birth_date" => "2026-03-13",
               "email" => "some email",
               "first_name" => "some first_name",
               "height" => "120.5",
               "height_unit" => 42,
               "last_name" => "some last_name",
               "weight" => "120.5",
               "weight_unit" => 42
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/users", user: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update user" do
    setup [:create_user]

    test "renders user when data is valid", %{conn: conn, user: %User{id: id} = user} do
      conn = put(conn, ~p"/api/users/#{user}", user: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, ~p"/api/users/#{id}")

      assert %{
               "id" => ^id,
               "biological_sex" => 43,
               "birth_date" => "2026-03-14",
               "email" => "some updated email",
               "first_name" => "some updated first_name",
               "height" => "456.7",
               "height_unit" => 43,
               "last_name" => "some updated last_name",
               "weight" => "456.7",
               "weight_unit" => 43
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, user: user} do
      conn = put(conn, ~p"/api/users/#{user}", user: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete user" do
    setup [:create_user]

    test "deletes chosen user", %{conn: conn, user: user} do
      conn = delete(conn, ~p"/api/users/#{user}")
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, ~p"/api/users/#{user}")
      end
    end
  end

  defp create_user(_) do
    user = user_fixture()

    %{user: user}
  end
end
