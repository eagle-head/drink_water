defmodule DrinkWaterWeb.ErrorCatalogTest do
  use DrinkWaterWeb.ConnCase, async: true

  alias DrinkWaterWeb.ErrorCatalog

  @test_base_uri "http://www.example.com"

  defp conn_with_path(path) do
    build_conn(:get, path)
  end

  describe "build/1 (generic 500)" do
    test "returns internal server error as ProblemDetail struct" do
      result = ErrorCatalog.build(conn_with_path("/api/users"))

      assert %ProblemDetail{} = result
      assert result.type == "https://www.drinkwater.com.br/internal-server-error"
      assert result.title == "Internal Server Error"
      assert result.status == 500

      assert result.detail ==
               "An unexpected error occurred. Please try again later or contact support."

      assert result.instance == @test_base_uri <> "/api/users"
    end
  end

  describe "build/2 (single-key catalog)" do
    test "bad_request returns 400 with specific type and detail" do
      result = ErrorCatalog.build(conn_with_path("/api/users"), :bad_request)

      assert result.type == "https://www.drinkwater.com.br/invalid-argument"
      assert result.title == "Bad Request"
      assert result.status == 400
      assert result.detail == "An invalid argument was provided."
      assert result.instance == @test_base_uri <> "/api/users"
    end

    test "parsing_error returns 400" do
      result = ErrorCatalog.build(conn_with_path("/api/users"), :parsing_error)
      assert result.type == "https://www.drinkwater.com.br/parsing-error"
      assert result.status == 400
    end

    test "rate_limit_exceeded returns 429" do
      result =
        ErrorCatalog.build(conn_with_path("/api/users/1/water_intakes"), :rate_limit_exceeded)

      assert result.type == "https://www.drinkwater.com.br/rate-limit-exceeded"
      assert result.status == 429
      assert result.detail == "Too many requests. Please wait before trying again."
      assert result.instance == @test_base_uri <> "/api/users/1/water_intakes"
    end
  end

  describe "build/3 (composite-key catalog)" do
    test "not_found user returns 404" do
      result = ErrorCatalog.build(conn_with_path("/api/users/999"), :not_found, :user)
      assert result.type == "https://www.drinkwater.com.br/user-not-found"
      assert result.title == "Not Found"
      assert result.status == 404
      assert result.detail == "The requested user account was not found."
      assert result.instance == @test_base_uri <> "/api/users/999"
    end

    test "not_found alarm_settings returns 404" do
      result =
        ErrorCatalog.build(
          conn_with_path("/api/users/1/alarm_settings"),
          :not_found,
          :alarm_settings
        )

      assert result.type == "https://www.drinkwater.com.br/alarm-settings-not-found"
      assert result.status == 404
    end

    test "not_found water_intake returns 404" do
      result =
        ErrorCatalog.build(
          conn_with_path("/api/users/1/water_intakes/99"),
          :not_found,
          :water_intake
        )

      assert result.type == "https://www.drinkwater.com.br/waterintake-not-found"
      assert result.status == 404
    end

    test "conflict user returns 409" do
      result = ErrorCatalog.build(conn_with_path("/api/users"), :conflict, :user)
      assert result.type == "https://www.drinkwater.com.br/user-already-exists"
      assert result.status == 409
    end

    test "conflict alarm_settings returns 409" do
      result =
        ErrorCatalog.build(
          conn_with_path("/api/users/1/alarm_settings"),
          :conflict,
          :alarm_settings
        )

      assert result.type == "https://www.drinkwater.com.br/alarm-settings-already-exists"
      assert result.status == 409
    end

    test "conflict water_intake returns 409" do
      result =
        ErrorCatalog.build(conn_with_path("/api/users/1/water_intakes"), :conflict, :water_intake)

      assert result.type == "https://www.drinkwater.com.br/waterintake-duplicate-datetime"
      assert result.status == 409
    end
  end

  describe "from_changeset/2" do
    test "returns 422 with validation errors in properties" do
      changeset =
        %DrinkWater.UserManagement.User{}
        |> Ecto.Changeset.change()
        |> Ecto.Changeset.add_error(:email, "can't be blank")
        |> Ecto.Changeset.add_error(:first_name, "is too short")

      result = ErrorCatalog.from_changeset(conn_with_path("/api/users"), changeset)

      assert %ProblemDetail{} = result
      assert result.type == "https://www.drinkwater.com.br/validation-error"
      assert result.title == "Unprocessable Content"
      assert result.status == 422
      assert result.detail == "One or more fields are invalid. Please correct them and try again."
      assert result.instance == @test_base_uri <> "/api/users"
      assert result.properties["errors"][:email] == ["can't be blank"]
      assert result.properties["errors"][:first_name] == ["is too short"]
    end

    test "translates error message placeholders" do
      changeset =
        %DrinkWater.UserManagement.User{}
        |> Ecto.Changeset.change()
        |> Ecto.Changeset.add_error(:first_name, "should be at least %{count} character(s)",
          count: 2,
          validation: :length,
          kind: :min
        )

      result = ErrorCatalog.from_changeset(conn_with_path("/api/users"), changeset)
      assert result.properties["errors"][:first_name] == ["should be at least 2 character(s)"]
    end
  end
end
