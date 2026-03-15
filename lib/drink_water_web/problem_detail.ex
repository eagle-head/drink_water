defmodule DrinkWaterWeb.ProblemDetail do
  @moduledoc """
  Builds RFC 7807 Problem Detail responses.

  See: https://www.rfc-editor.org/rfc/rfc7807
  """

  @type_base "about:blank"

  @doc """
  Builds a problem detail map from a status code and optional detail message.
  """
  def build(status, detail \\ nil) do
    %{
      type: @type_base,
      title: title_for(status),
      status: status
    }
    |> maybe_put(:detail, detail)
  end

  @doc """
  Builds a problem detail map with validation errors from a changeset.
  """
  def from_changeset(%Ecto.Changeset{} = changeset, detail \\ "Validation failed") do
    build(422, detail)
    |> Map.put(:errors, translate_errors(changeset))
  end

  defp title_for(status) do
    Plug.Conn.Status.reason_phrase(status)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
