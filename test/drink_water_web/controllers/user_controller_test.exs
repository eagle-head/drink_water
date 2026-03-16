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
               "height" => 175.0,
               "height_unit" => "cm",
               "last_name" => "Doe",
               "weight" => 75.0,
               "weight_unit" => "kg"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors in RFC 7807 format when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/users", user: @invalid_attrs)
      assert {"content-type", "application/problem+json; charset=utf-8"} in conn.resp_headers
      response = json_response(conn, 422)
      assert response["type"] == "https://www.drinkwater.com.br/validation-error"
      assert response["title"] == "Unprocessable Content"
      assert response["status"] == 422

      assert response["detail"] ==
               "One or more fields are invalid. Please correct them and try again."

      assert response["instance"] == "/api/users"
      assert response["errors"] != %{}
    end

    test "returns 422 when name contains invalid characters", %{conn: conn} do
      invalid_name_attrs = %{@create_attrs | first_name: "John123", last_name: "Doe<>"}
      conn = post(conn, ~p"/api/users", user: invalid_name_attrs)
      response = json_response(conn, 422)
      assert response["type"] == "https://www.drinkwater.com.br/validation-error"
      assert response["errors"]["first_name"]
      assert response["errors"]["last_name"]
    end

    test "returns 409 when creating user with duplicate email", %{conn: conn} do
      post(conn, ~p"/api/users", user: @create_attrs)
      conn = post(conn, ~p"/api/users", user: @create_attrs)
      assert {"content-type", "application/problem+json; charset=utf-8"} in conn.resp_headers
      response = json_response(conn, 409)
      assert response["type"] == "https://www.drinkwater.com.br/user-already-exists"
      assert response["title"] == "Conflict"
      assert response["status"] == 409
      assert response["detail"] == "A user with this email address already exists."
      assert response["instance"] == "/api/users"
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
               "height" => 168.0,
               "height_unit" => "cm",
               "last_name" => "Doe",
               "weight" => 65.0,
               "weight_unit" => "kg"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors in RFC 7807 format when data is invalid", %{conn: conn, user: user} do
      conn = put(conn, ~p"/api/users/#{user}", user: @invalid_attrs)
      response = json_response(conn, 422)
      assert response["type"] == "https://www.drinkwater.com.br/validation-error"
      assert response["title"] == "Unprocessable Content"
      assert response["status"] == 422

      assert response["detail"] ==
               "One or more fields are invalid. Please correct them and try again."

      assert response["instance"] == "/api/users/#{user.id}"
      assert response["errors"] != %{}
    end
  end

  describe "delete user" do
    setup [:create_user]

    test "deletes chosen user", %{conn: conn, user: user} do
      conn = delete(conn, ~p"/api/users/#{user}")
      assert response(conn, 204)

      conn = get(conn, ~p"/api/users/#{user}")
      response = json_response(conn, 404)
      assert response["type"] == "https://www.drinkwater.com.br/user-not-found"
      assert response["title"] == "Not Found"
      assert response["status"] == 404
      assert response["detail"] == "The requested user account was not found."
      assert response["instance"] == "/api/users/#{user.id}"
    end
  end

  describe "not found" do
    test "show returns 404 in RFC 7807 format for nonexistent user", %{conn: conn} do
      conn = get(conn, ~p"/api/users/0")
      assert {"content-type", "application/problem+json; charset=utf-8"} in conn.resp_headers
      response = json_response(conn, 404)
      assert response["type"] == "https://www.drinkwater.com.br/user-not-found"
      assert response["title"] == "Not Found"
      assert response["status"] == 404
      assert response["detail"] == "The requested user account was not found."
      assert response["instance"] == "/api/users/0"
    end

    test "update returns 404 in RFC 7807 format for nonexistent user", %{conn: conn} do
      conn = put(conn, ~p"/api/users/0", user: @update_attrs)
      response = json_response(conn, 404)
      assert response["type"] == "https://www.drinkwater.com.br/user-not-found"
      assert response["title"] == "Not Found"
      assert response["status"] == 404
      assert response["detail"] == "The requested user account was not found."
      assert response["instance"] == "/api/users/0"
    end

    test "delete returns 204 for nonexistent user (idempotent)", %{conn: conn} do
      conn = delete(conn, ~p"/api/users/0")
      assert response(conn, 204)
    end

    test "show returns 404 for non-integer id", %{conn: conn} do
      conn = get(conn, ~p"/api/users/abc")
      response = json_response(conn, 404)
      assert response["type"] == "https://www.drinkwater.com.br/user-not-found"
      assert response["title"] == "Not Found"
      assert response["status"] == 404
      assert response["detail"] == "The requested user account was not found."
      assert response["instance"] == "/api/users/abc"
    end
  end

  describe "malformed requests" do
    test "returns 400 parsing-error for malformed JSON body", %{conn: conn} do
      {status, headers, body} =
        assert_error_sent(400, fn ->
          conn
          |> put_req_header("content-type", "application/json")
          |> post(~p"/api/users", "{this is not valid json}")
        end)

      assert status == 400
      assert {"content-type", "application/json; charset=utf-8"} in headers
      response = Jason.decode!(body)
      assert response["type"] == "https://www.drinkwater.com.br/parsing-error"
      assert response["title"] == "Bad Request"
      assert response["status"] == 400

      assert response["detail"] ==
               "Unable to process the request. Please check that your data is properly formatted."

      assert response["instance"] == "/api/users"
    end

    test "returns 400 invalid-argument when user key is missing from body", %{conn: conn} do
      {status, headers, body} =
        assert_error_sent(400, fn ->
          post(conn, ~p"/api/users", %{"not_user" => %{"email" => "test@test.com"}})
        end)

      assert status == 400
      assert {"content-type", "application/json; charset=utf-8"} in headers
      response = Jason.decode!(body)
      assert response["type"] == "https://www.drinkwater.com.br/invalid-argument"
      assert response["title"] == "Bad Request"
      assert response["status"] == 400
      assert response["detail"] == "An invalid argument was provided."
      assert response["instance"] == "/api/users"
    end
  end

  defp create_user(_) do
    user = user_fixture()

    %{user: user}
  end
end
