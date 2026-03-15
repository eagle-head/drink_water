defmodule DrinkWaterWeb.ProblemDetailTest do
  use DrinkWater.DataCase, async: true

  alias DrinkWaterWeb.ProblemDetail

  describe "build/2" do
    test "builds RFC 7807 response with status only" do
      assert ProblemDetail.build(404) == %{
               type: "about:blank",
               title: "Not Found",
               status: 404
             }
    end

    test "builds RFC 7807 response with detail message" do
      assert ProblemDetail.build(400, "Invalid cursor") == %{
               type: "about:blank",
               title: "Bad Request",
               status: 400,
               detail: "Invalid cursor"
             }
    end

    test "omits detail key when nil" do
      result = ProblemDetail.build(500)
      refute Map.has_key?(result, :detail)
    end
  end

  describe "from_changeset/1" do
    test "builds RFC 7807 response with validation errors" do
      changeset =
        %DrinkWater.UserManagement.User{}
        |> Ecto.Changeset.change()
        |> Ecto.Changeset.add_error(:email, "can't be blank")
        |> Ecto.Changeset.add_error(:first_name, "is too short")

      result = ProblemDetail.from_changeset(changeset)

      assert result.type == "about:blank"
      assert result.title == "Unprocessable Content"
      assert result.status == 422
      assert result.detail == "Validation failed"
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

      result = ProblemDetail.from_changeset(changeset)
      assert result.errors[:first_name] == ["should be at least 2 character(s)"]
    end
  end
end
