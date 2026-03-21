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
end
