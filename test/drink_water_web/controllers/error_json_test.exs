defmodule DrinkWaterWeb.ErrorJSONTest do
  use DrinkWaterWeb.ConnCase, async: true

  test "renders 400 in RFC 7807 format" do
    assert DrinkWaterWeb.ErrorJSON.render("400.json", %{}) == %{
             type: "about:blank",
             title: "Bad Request",
             status: 400
           }
  end

  test "renders 404 in RFC 7807 format" do
    assert DrinkWaterWeb.ErrorJSON.render("404.json", %{}) == %{
             type: "about:blank",
             title: "Not Found",
             status: 404
           }
  end

  test "renders 500 in RFC 7807 format" do
    assert DrinkWaterWeb.ErrorJSON.render("500.json", %{}) == %{
             type: "about:blank",
             title: "Internal Server Error",
             status: 500
           }
  end

  test "falls back to 500 for unexpected template name" do
    assert DrinkWaterWeb.ErrorJSON.render("unknown.json", %{}) == %{
             type: "about:blank",
             title: "Internal Server Error",
             status: 500
           }
  end
end
