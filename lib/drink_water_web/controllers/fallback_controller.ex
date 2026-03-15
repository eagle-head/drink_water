defmodule DrinkWaterWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use DrinkWaterWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_problem_content_type()
    |> put_status(:unprocessable_entity)
    |> put_view(json: DrinkWaterWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end

  def call(conn, {:error, :bad_request}) do
    conn
    |> put_problem_content_type()
    |> put_status(:bad_request)
    |> put_view(json: DrinkWaterWeb.ErrorJSON)
    |> render(:"400")
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_problem_content_type()
    |> put_status(:not_found)
    |> put_view(json: DrinkWaterWeb.ErrorJSON)
    |> render(:"404")
  end

  defp put_problem_content_type(conn) do
    put_resp_content_type(conn, "application/problem+json")
  end
end
