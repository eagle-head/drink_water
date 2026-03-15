defmodule DrinkWaterWeb.ErrorJSON do
  @moduledoc """
  Renders API error responses as RFC 7807 Problem Details.

  Serves two paths:
  - `error/1` — called by FallbackController for business errors
  - `render/2` — called by Endpoint render_errors for unhandled exceptions
  """

  alias DrinkWaterWeb.ProblemDetail

  @doc "Called by FallbackController — returns the pre-built problem map."
  def error(%{problem: problem}), do: problem

  @doc "Called by Endpoint render_errors — dispatches by exception type."
  def render(_template, %{conn: conn, reason: %Plug.Parsers.ParseError{}}) do
    ProblemDetail.build(conn, :parsing_error)
  end

  def render(_template, %{conn: conn, reason: %Phoenix.ActionClauseError{}}) do
    ProblemDetail.build(conn, :bad_request)
  end

  def render(_template, %{conn: conn}) do
    ProblemDetail.build(conn)
  end
end
