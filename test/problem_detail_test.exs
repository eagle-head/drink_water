defmodule ProblemDetailTest do
  use ExUnit.Case, async: true

  describe "new/1" do
    test "creates a problem detail with status and auto-resolved title" do
      pd = ProblemDetail.new(404)

      assert %ProblemDetail{} = pd
      assert pd.status == 404
      assert pd.title == "Not Found"
      assert pd.type == nil
      assert pd.detail == nil
      assert pd.instance == nil
      assert pd.properties == %{}
    end

    test "resolves title for common status codes" do
      assert ProblemDetail.new(400).title == "Bad Request"
      assert ProblemDetail.new(409).title == "Conflict"
      assert ProblemDetail.new(422).title == "Unprocessable Content"
      assert ProblemDetail.new(429).title == "Too Many Requests"
      assert ProblemDetail.new(500).title == "Internal Server Error"
    end

    test "defaults title to nil for unknown status codes" do
      pd = ProblemDetail.new(499)
      assert pd.status == 499
      assert pd.title == nil
    end
  end

  describe "new/2" do
    test "accepts optional fields via keyword list" do
      pd =
        ProblemDetail.new(409,
          type: "https://example.com/conflict",
          detail: "Already exists",
          instance: "https://example.com/api/users/1"
        )

      assert pd.status == 409
      assert pd.type == "https://example.com/conflict"
      assert pd.detail == "Already exists"
      assert pd.instance == "https://example.com/api/users/1"
      assert pd.title == "Conflict"
    end

    test "title in opts overrides auto-resolved value" do
      pd = ProblemDetail.new(500, title: "Erro Interno")
      assert pd.title == "Erro Interno"
    end
  end

  describe "put_type/2" do
    test "sets the type URI" do
      pd = ProblemDetail.new(404) |> ProblemDetail.put_type("https://example.com/not-found")
      assert pd.type == "https://example.com/not-found"
    end
  end

  describe "put_title/2" do
    test "overrides the auto-resolved title" do
      pd = ProblemDetail.new(500) |> ProblemDetail.put_title("Erro Interno")
      assert pd.title == "Erro Interno"
    end
  end

  describe "put_detail/2" do
    test "sets the detail message" do
      pd = ProblemDetail.new(404) |> ProblemDetail.put_detail("User 999 not found")
      assert pd.detail == "User 999 not found"
    end
  end

  describe "put_instance/2" do
    test "sets the instance URI" do
      pd =
        ProblemDetail.new(404) |> ProblemDetail.put_instance("https://example.com/api/users/999")

      assert pd.instance == "https://example.com/api/users/999"
    end
  end

  describe "put_extension/3" do
    test "adds an extension to properties with string key" do
      pd = ProblemDetail.new(422) |> ProblemDetail.put_extension("errors", %{name: ["required"]})
      assert pd.properties == %{"errors" => %{name: ["required"]}}
    end

    test "converts atom keys to strings" do
      pd = ProblemDetail.new(500) |> ProblemDetail.put_extension(:trace_id, "abc-123")
      assert pd.properties == %{"trace_id" => "abc-123"}
    end

    test "multiple extensions accumulate" do
      pd =
        ProblemDetail.new(400)
        |> ProblemDetail.put_extension("trace_id", "abc")
        |> ProblemDetail.put_extension("request_id", "xyz")

      assert pd.properties == %{"trace_id" => "abc", "request_id" => "xyz"}
    end
  end

  describe "pipe composition" do
    test "builds a complete problem detail via pipes" do
      pd =
        ProblemDetail.new(422)
        |> ProblemDetail.put_type("https://example.com/validation-error")
        |> ProblemDetail.put_detail("Invalid input")
        |> ProblemDetail.put_instance("https://example.com/api/users")
        |> ProblemDetail.put_extension("errors", %{name: ["required"]})

      assert pd.status == 422
      assert pd.title == "Unprocessable Content"
      assert pd.type == "https://example.com/validation-error"
      assert pd.detail == "Invalid input"
      assert pd.instance == "https://example.com/api/users"
      assert pd.properties == %{"errors" => %{name: ["required"]}}
    end
  end
end
