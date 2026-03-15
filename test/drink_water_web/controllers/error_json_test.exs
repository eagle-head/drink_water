defmodule DrinkWaterWeb.ErrorJSONTest do
  use DrinkWaterWeb.ConnCase, async: true

  alias DrinkWaterWeb.ErrorJSON

  describe "error/1 (FallbackController path)" do
    test "returns the problem map as-is" do
      problem = %{type: "test", title: "Test", status: 400, detail: "test", instance: "/test"}
      assert ErrorJSON.error(%{problem: problem}) == problem
    end
  end

  describe "render/2 (Endpoint render_errors path)" do
    test "returns generic 500 for unknown exceptions" do
      conn = build_conn(:get, "/api/users")
      result = ErrorJSON.render("500.json", %{conn: conn, reason: %RuntimeError{message: "boom"}})

      assert result.type == "https://www.drinkwater.com.br/internal-server-error"
      assert result.status == 500
      assert result.instance == "/api/users"
    end

    test "returns parsing-error for Plug.Parsers.ParseError" do
      conn = build_conn(:post, "/api/users")
      reason = %Plug.Parsers.ParseError{exception: %Jason.DecodeError{data: ""}}
      result = ErrorJSON.render("400.json", %{conn: conn, reason: reason})

      assert result.type == "https://www.drinkwater.com.br/parsing-error"
      assert result.status == 400
      assert result.instance == "/api/users"
    end

    test "returns invalid-argument for Phoenix.ActionClauseError" do
      conn = build_conn(:post, "/api/users")
      reason = %Phoenix.ActionClauseError{args: []}
      result = ErrorJSON.render("400.json", %{conn: conn, reason: reason})

      assert result.type == "https://www.drinkwater.com.br/invalid-argument"
      assert result.status == 400
      assert result.instance == "/api/users"
    end
  end
end
