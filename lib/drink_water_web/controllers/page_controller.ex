defmodule DrinkWaterWeb.PageController do
  use DrinkWaterWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
