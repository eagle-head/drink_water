defmodule DrinkWaterWeb.ErrorJSON do
  @moduledoc """
  Renders API error responses as RFC 9457 Problem Details.

  Serves two paths:
  - `error/1` — called by FallbackController for business errors
  - `render/2` — called by Endpoint render_errors for unhandled exceptions
  """

  alias DrinkWaterWeb.ErrorCatalog

  @doc "Called by FallbackController — returns the pre-built ProblemDetail struct."
  def error(%{problem: %ProblemDetail{} = problem}), do: problem

  @doc "Called by Endpoint render_errors — dispatches by exception type."
  def render(_template, %{conn: conn, reason: %Plug.Parsers.ParseError{}}) do
    ErrorCatalog.build(conn, :parsing_error)
  end

  def render(_template, %{conn: conn, reason: %Phoenix.ActionClauseError{}}) do
    ErrorCatalog.build(conn, :bad_request)
  end

  def render(_template, %{conn: conn}) do
    ErrorCatalog.build(conn)
  end
end
