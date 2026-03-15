defmodule DrinkWaterWeb.ProblemDetailTest do
  use DrinkWaterWeb.ConnCase, async: true

  alias DrinkWaterWeb.ProblemDetail

  defp conn_with_path(path) do
    build_conn(:get, path)
  end

  describe "build/1 (generic 500)" do
    test "returns internal server error with all RFC 7807 fields" do
      result = ProblemDetail.build(conn_with_path("/api/users"))

      assert result == %{
               type: "https://www.drinkwater.com.br/internal-server-error",
               title: "Internal Server Error",
               status: 500,
               detail: "An unexpected error occurred. Please try again later or contact support.",
               instance: "/api/users"
             }
    end
  end

  describe "build/2 (single-key catalog)" do
    test "bad_request returns 400 with specific type and detail" do
      result = ProblemDetail.build(conn_with_path("/api/users"), :bad_request)

      assert result == %{
               type: "https://www.drinkwater.com.br/invalid-argument",
               title: "Bad Request",
               status: 400,
               detail: "An invalid argument was provided.",
               instance: "/api/users"
             }
    end

    test "parsing_error returns 400 with parsing-error type" do
      result = ProblemDetail.build(conn_with_path("/api/users"), :parsing_error)

      assert result == %{
               type: "https://www.drinkwater.com.br/parsing-error",
               title: "Bad Request",
               status: 400,
               detail:
                 "Unable to process the request. Please check that your data is properly formatted.",
               instance: "/api/users"
             }
    end

    test "rate_limit_exceeded returns 429" do
      result =
        ProblemDetail.build(conn_with_path("/api/users/1/water_intakes"), :rate_limit_exceeded)

      assert result == %{
               type: "https://www.drinkwater.com.br/rate-limit-exceeded",
               title: "Too Many Requests",
               status: 429,
               detail: "Too many requests. Please wait before trying again.",
               instance: "/api/users/1/water_intakes"
             }
    end
  end

  describe "build/3 (composite-key catalog)" do
    test "not_found user returns 404 with user-not-found type" do
      result = ProblemDetail.build(conn_with_path("/api/users/999"), :not_found, :user)

      assert result == %{
               type: "https://www.drinkwater.com.br/user-not-found",
               title: "Not Found",
               status: 404,
               detail: "The requested user account was not found.",
               instance: "/api/users/999"
             }
    end

    test "not_found alarm_settings" do
      result =
        ProblemDetail.build(
          conn_with_path("/api/users/1/alarm_settings"),
          :not_found,
          :alarm_settings
        )

      assert result == %{
               type: "https://www.drinkwater.com.br/alarm-settings-not-found",
               title: "Not Found",
               status: 404,
               detail: "The requested alarm settings were not found.",
               instance: "/api/users/1/alarm_settings"
             }
    end

    test "not_found water_intake" do
      result =
        ProblemDetail.build(
          conn_with_path("/api/users/1/water_intakes/99"),
          :not_found,
          :water_intake
        )

      assert result == %{
               type: "https://www.drinkwater.com.br/waterintake-not-found",
               title: "Not Found",
               status: 404,
               detail: "The requested water intake record was not found.",
               instance: "/api/users/1/water_intakes/99"
             }
    end

    test "conflict user returns 409 with user-already-exists type" do
      result = ProblemDetail.build(conn_with_path("/api/users"), :conflict, :user)

      assert result == %{
               type: "https://www.drinkwater.com.br/user-already-exists",
               title: "Conflict",
               status: 409,
               detail: "A user with this email address already exists.",
               instance: "/api/users"
             }
    end

    test "conflict alarm_settings" do
      result =
        ProblemDetail.build(
          conn_with_path("/api/users/1/alarm_settings"),
          :conflict,
          :alarm_settings
        )

      assert result == %{
               type: "https://www.drinkwater.com.br/alarm-settings-already-exists",
               title: "Conflict",
               status: 409,
               detail: "Alarm settings already exist for this user.",
               instance: "/api/users/1/alarm_settings"
             }
    end

    test "conflict water_intake" do
      result =
        ProblemDetail.build(
          conn_with_path("/api/users/1/water_intakes"),
          :conflict,
          :water_intake
        )

      assert result == %{
               type: "https://www.drinkwater.com.br/waterintake-duplicate-datetime",
               title: "Conflict",
               status: 409,
               detail: "A water intake record already exists for the specified date and time.",
               instance: "/api/users/1/water_intakes"
             }
    end
  end

  describe "from_changeset/2" do
    test "returns 422 with validation errors" do
      changeset =
        %DrinkWater.UserManagement.User{}
        |> Ecto.Changeset.change()
        |> Ecto.Changeset.add_error(:email, "can't be blank")
        |> Ecto.Changeset.add_error(:first_name, "is too short")

      result = ProblemDetail.from_changeset(conn_with_path("/api/users"), changeset)

      assert result.type == "https://www.drinkwater.com.br/validation-error"
      assert result.title == "Unprocessable Content"
      assert result.status == 422
      assert result.detail == "One or more fields are invalid. Please correct them and try again."
      assert result.instance == "/api/users"
      assert result.errors[:email] == ["can't be blank"]
      assert result.errors[:first_name] == ["is too short"]
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

      result = ProblemDetail.from_changeset(conn_with_path("/api/users"), changeset)
      assert result.errors[:first_name] == ["should be at least 2 character(s)"]
    end
  end
end
