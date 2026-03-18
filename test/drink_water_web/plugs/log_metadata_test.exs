defmodule DrinkWaterWeb.Plugs.LogMetadataTest do
  use DrinkWaterWeb.ConnCase, async: true

  alias DrinkWaterWeb.Plugs.LogMetadata

  describe "call/2" do
    test "sets user_id metadata from user_id param", %{conn: conn} do
      conn = %{conn | params: %{"user_id" => "42"}}
      LogMetadata.call(conn, [])
      assert Logger.metadata()[:user_id] == "42"
    end

    test "sets user_id metadata from id param when user_id absent", %{conn: conn} do
      conn = %{conn | params: %{"id" => "99"}}
      LogMetadata.call(conn, [])
      assert Logger.metadata()[:user_id] == "99"
    end

    test "prefers user_id over id when both present", %{conn: conn} do
      conn = %{conn | params: %{"user_id" => "42", "id" => "99"}}
      LogMetadata.call(conn, [])
      assert Logger.metadata()[:user_id] == "42"
    end

    test "does not crash when no user_id or id param", %{conn: conn} do
      conn = %{conn | params: %{}}
      result = LogMetadata.call(conn, [])
      assert result == conn
    end

    test "returns conn unchanged", %{conn: conn} do
      conn = %{conn | params: %{"user_id" => "42"}}
      assert LogMetadata.call(conn, []) == conn
    end
  end

  describe "init/1" do
    test "passes options through" do
      assert LogMetadata.init(foo: :bar) == [foo: :bar]
    end
  end
end
