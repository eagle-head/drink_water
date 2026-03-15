defmodule DrinkWaterWeb.ProblemDetail do
  @moduledoc """
  Builds RFC 7807 Problem Detail responses.

  See: https://www.rfc-editor.org/rfc/rfc7807
  """

  use Gettext, backend: DrinkWaterWeb.Gettext

  # Extraction hints — these calls let `mix gettext.extract` discover the strings.
  # At runtime, messages are resolved dynamically via Gettext.dgettext/3 in build_from_entry/2.
  dgettext_noop("errors", "The requested user account was not found.")
  dgettext_noop("errors", "The requested alarm settings were not found.")
  dgettext_noop("errors", "The requested water intake record was not found.")
  dgettext_noop("errors", "A user with this email address already exists.")
  dgettext_noop("errors", "Alarm settings already exist for this user.")
  dgettext_noop("errors", "A water intake record already exists for the specified date and time.")
  dgettext_noop("errors", "An invalid argument was provided.")

  dgettext_noop(
    "errors",
    "Unable to process the request. Please check that your data is properly formatted."
  )

  dgettext_noop("errors", "Too many requests. Please wait before trying again.")
  dgettext_noop("errors", "One or more fields are invalid. Please correct them and try again.")

  dgettext_noop(
    "errors",
    "An unexpected error occurred. Please try again later or contact support."
  )

  @type_base_url "https://www.drinkwater.com.br"

  @error_catalog %{
    {:not_found, :user} => %{
      status: 404,
      slug: "user-not-found",
      message: "The requested user account was not found."
    },
    {:not_found, :alarm_settings} => %{
      status: 404,
      slug: "alarm-settings-not-found",
      message: "The requested alarm settings were not found."
    },
    {:not_found, :water_intake} => %{
      status: 404,
      slug: "waterintake-not-found",
      message: "The requested water intake record was not found."
    },
    {:conflict, :user} => %{
      status: 409,
      slug: "user-already-exists",
      message: "A user with this email address already exists."
    },
    {:conflict, :alarm_settings} => %{
      status: 409,
      slug: "alarm-settings-already-exists",
      message: "Alarm settings already exist for this user."
    },
    {:conflict, :water_intake} => %{
      status: 409,
      slug: "waterintake-duplicate-datetime",
      message: "A water intake record already exists for the specified date and time."
    },
    :bad_request => %{
      status: 400,
      slug: "invalid-argument",
      message: "An invalid argument was provided."
    },
    :parsing_error => %{
      status: 400,
      slug: "parsing-error",
      message: "Unable to process the request. Please check that your data is properly formatted."
    },
    :rate_limit_exceeded => %{
      status: 429,
      slug: "rate-limit-exceeded",
      message: "Too many requests. Please wait before trying again."
    },
    :validation_error => %{
      status: 422,
      slug: "validation-error",
      message: "One or more fields are invalid. Please correct them and try again."
    },
    :internal_server_error => %{
      status: 500,
      slug: "internal-server-error",
      message: "An unexpected error occurred. Please try again later or contact support."
    }
  }

  @spec build(Plug.Conn.t()) :: map()
  def build(%Plug.Conn{} = conn) do
    build_from_entry(conn, @error_catalog[:internal_server_error])
  end

  @spec build(Plug.Conn.t(), atom()) :: map()
  def build(%Plug.Conn{} = conn, error_key) when is_atom(error_key) do
    build_from_entry(conn, Map.fetch!(@error_catalog, error_key))
  end

  @spec build(Plug.Conn.t(), atom(), atom()) :: map()
  def build(%Plug.Conn{} = conn, category, resource)
      when is_atom(category) and is_atom(resource) do
    build_from_entry(conn, Map.fetch!(@error_catalog, {category, resource}))
  end

  @spec from_changeset(Plug.Conn.t(), Ecto.Changeset.t()) :: map()
  def from_changeset(%Plug.Conn{} = conn, %Ecto.Changeset{} = changeset) do
    entry = @error_catalog[:validation_error]

    build_from_entry(conn, entry)
    |> Map.put(:errors, translate_errors(changeset))
  end

  defp build_from_entry(conn, entry) do
    %{
      type: "#{@type_base_url}/#{entry.slug}",
      title: Plug.Conn.Status.reason_phrase(entry.status),
      status: entry.status,
      detail: Gettext.dgettext(DrinkWaterWeb.Gettext, "errors", entry.message),
      instance: conn.request_path
    }
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
