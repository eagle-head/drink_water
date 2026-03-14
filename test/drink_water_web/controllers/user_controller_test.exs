defmodule DrinkWaterWeb.UserControllerTest do
  use DrinkWaterWeb.ConnCase

  import DrinkWater.UserManagementFixtures
  alias DrinkWater.UserManagement.User

  @create_attrs %{
    email: "john.doe@example.com",
    first_name: "John",
    last_name: "Doe",
    birth_date: ~D[1990-05-15],
    biological_sex: :male,
    weight: "75.0",
    weight_unit: :kg,
    height: "175.0",
    height_unit: :cm
  }
  @update_attrs %{
    email: "jane.doe@example.com",
    first_name: "Jane",
    last_name: "Doe",
    birth_date: ~D[1992-08-20],
    biological_sex: :female,
    weight: "65.0",
    weight_unit: :kg,
    height: "168.0",
    height_unit: :cm
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
               "biological_sex" => "male",
               "birth_date" => "1990-05-15",
               "email" => "john.doe@example.com",
               "first_name" => "John",
               "height" => "175.0",
               "height_unit" => "cm",
               "last_name" => "Doe",
               "weight" => "75.0",
               "weight_unit" => "kg"
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
               "biological_sex" => "female",
               "birth_date" => "1992-08-20",
               "email" => "jane.doe@example.com",
               "first_name" => "Jane",
               "height" => "168.0",
               "height_unit" => "cm",
               "last_name" => "Doe",
               "weight" => "65.0",
               "weight_unit" => "kg"
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

      conn = get(conn, ~p"/api/users/#{user}")
      assert json_response(conn, 404)
    end
  end

  describe "not found" do
    test "show returns 404 for nonexistent user", %{conn: conn} do
      conn = get(conn, ~p"/api/users/0")
      assert json_response(conn, 404)
    end

    test "update returns 404 for nonexistent user", %{conn: conn} do
      conn = put(conn, ~p"/api/users/0", user: @update_attrs)
      assert json_response(conn, 404)
    end

    test "delete returns 404 for nonexistent user", %{conn: conn} do
      conn = delete(conn, ~p"/api/users/0")
      assert json_response(conn, 404)
    end
  end

  defp create_user(_) do
    user = user_fixture()

    %{user: user}
  end
end
