defmodule DrinkWaterWeb.Plugs.InputSanitizerTest do
  use DrinkWaterWeb.ConnCase

  alias DrinkWaterWeb.Plugs.InputSanitizer

  describe "sanitize/1" do
    test "removes null bytes from string params" do
      conn =
        build_conn(:get, "/", %{"name" => "John\0Doe"})
        |> InputSanitizer.call([])

      assert conn.params["name"] == "JohnDoe"
    end

    test "trims whitespace from string params" do
      conn =
        build_conn(:get, "/", %{"name" => "  John  "})
        |> InputSanitizer.call([])

      assert conn.params["name"] == "John"
    end

    test "sanitizes nested maps" do
      conn =
        build_conn(:post, "/", %{"user" => %{"name" => " John\0 "}})
        |> InputSanitizer.call([])

      assert conn.params["user"]["name"] == "John"
    end

    test "sanitizes lists" do
      conn =
        build_conn(:post, "/", %{"tags" => [" foo\0 ", " bar "]})
        |> InputSanitizer.call([])

      assert conn.params["tags"] == ["foo", "bar"]
    end

    test "leaves non-string values unchanged in nested body" do
      conn =
        build_conn(:post, "/", %{
          "data" => %{"count" => 42, "ratio" => 1.5, "active" => true, "nothing" => nil}
        })
        |> InputSanitizer.call([])

      assert conn.params["data"]["count"] == 42
      assert conn.params["data"]["ratio"] == 1.5
      assert conn.params["data"]["active"] == true
      assert conn.params["data"]["nothing"] == nil
    end

    test "sanitizes body_params as well" do
      conn =
        build_conn(:post, "/", %{"name" => "\0test\0"})
        |> InputSanitizer.call([])

      assert conn.body_params["name"] == "test"
    end

    test "does not crash when body_params is unfetched" do
      conn = build_conn(:get, "/api/test")
      assert %Plug.Conn{} = InputSanitizer.call(conn, [])
    end
  end

  describe "end-to-end: null bytes rejected before database" do
    setup %{conn: conn} do
      {:ok, conn: put_req_header(conn, "accept", "application/json")}
    end

    test "null bytes in user email are stripped", %{conn: conn} do
      attrs = %{
        email: "john\0@example.com",
        first_name: "John",
        last_name: "Doe",
        birth_date: "1990-05-15",
        biological_sex: "male",
        weight: "75.0",
        weight_unit: "kg",
        height: "175.0",
        height_unit: "cm"
      }

      conn = post(conn, ~p"/api/users", user: attrs)
      assert %{"email" => "john@example.com"} = json_response(conn, 201)["data"]
    end

    test "whitespace-only first_name is rejected after trimming", %{conn: conn} do
      attrs = %{
        email: "blank@example.com",
        first_name: "   ",
        last_name: "Doe",
        birth_date: "1990-05-15",
        biological_sex: "male",
        weight: "75.0",
        weight_unit: "kg",
        height: "175.0",
        height_unit: "cm"
      }

      conn = post(conn, ~p"/api/users", user: attrs)
      response = json_response(conn, 422)
      assert response["errors"]["first_name"]
    end
  end
end
