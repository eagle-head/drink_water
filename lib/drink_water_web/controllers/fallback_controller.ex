defmodule DrinkWaterWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses
  using RFC 7807 Problem Details.
  """
  use DrinkWaterWeb, :controller

  alias DrinkWaterWeb.ProblemDetail

  def call(conn, {:error, :not_found, resource}) when is_atom(resource) do
    conn
    |> put_problem_content_type()
    |> put_status(:not_found)
    |> put_view(json: DrinkWaterWeb.ErrorJSON)
    |> render(:error, problem: ProblemDetail.build(conn, :not_found, resource))
  end

  def call(conn, {:error, :conflict, resource}) when is_atom(resource) do
    conn
    |> put_problem_content_type()
    |> put_status(:conflict)
    |> put_view(json: DrinkWaterWeb.ErrorJSON)
    |> render(:error, problem: ProblemDetail.build(conn, :conflict, resource))
  end

  def call(conn, {:error, :bad_request}) do
    conn
    |> put_problem_content_type()
    |> put_status(:bad_request)
    |> put_view(json: DrinkWaterWeb.ErrorJSON)
    |> render(:error, problem: ProblemDetail.build(conn, :bad_request))
  end

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_problem_content_type()
    |> put_status(:unprocessable_entity)
    |> put_view(json: DrinkWaterWeb.ErrorJSON)
    |> render(:error, problem: ProblemDetail.from_changeset(conn, changeset))
  end

  defp put_problem_content_type(conn) do
    put_resp_content_type(conn, "application/problem+json")
  end
end
