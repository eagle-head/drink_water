defmodule DrinkWaterWeb.ErrorCatalog do
  @moduledoc """
  Project-specific error catalog that builds ProblemDetail structs
  from categorized error keys, with Gettext i18n and Plug.Conn integration.
  """

  use Gettext, backend: DrinkWaterWeb.Gettext

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

  @catalog %{
    {:not_found, :user} => {404, "user-not-found", "The requested user account was not found."},
    {:not_found, :alarm_settings} =>
      {404, "alarm-settings-not-found", "The requested alarm settings were not found."},
    {:not_found, :water_intake} =>
      {404, "waterintake-not-found", "The requested water intake record was not found."},
    {:conflict, :user} =>
      {409, "user-already-exists", "A user with this email address already exists."},
    {:conflict, :alarm_settings} =>
      {409, "alarm-settings-already-exists", "Alarm settings already exist for this user."},
    {:conflict, :water_intake} =>
      {409, "waterintake-duplicate-datetime",
       "A water intake record already exists for the specified date and time."},
    :bad_request => {400, "invalid-argument", "An invalid argument was provided."},
    :parsing_error =>
      {400, "parsing-error",
       "Unable to process the request. Please check that your data is properly formatted."},
    :rate_limit_exceeded =>
      {429, "rate-limit-exceeded", "Too many requests. Please wait before trying again."},
    :validation_error =>
      {422, "validation-error",
       "One or more fields are invalid. Please correct them and try again."},
    :internal_server_error =>
      {500, "internal-server-error",
       "An unexpected error occurred. Please try again later or contact support."}
  }

  @spec build(Plug.Conn.t()) :: ProblemDetail.t()
  def build(%Plug.Conn{} = conn) do
    build_from_entry(conn, @catalog[:internal_server_error])
  end

  @spec build(Plug.Conn.t(), atom()) :: ProblemDetail.t()
  def build(%Plug.Conn{} = conn, key) when is_atom(key) do
    build_from_entry(conn, Map.fetch!(@catalog, key))
  end

  @spec build(Plug.Conn.t(), atom(), atom()) :: ProblemDetail.t()
  def build(%Plug.Conn{} = conn, category, resource)
      when is_atom(category) and is_atom(resource) do
    build_from_entry(conn, Map.fetch!(@catalog, {category, resource}))
  end

  @spec from_changeset(Plug.Conn.t(), Ecto.Changeset.t()) :: ProblemDetail.t()
  def from_changeset(%Plug.Conn{} = conn, %Ecto.Changeset{} = changeset) do
    build(conn, :validation_error)
    |> ProblemDetail.put_extension("errors", translate_errors(changeset))
  end

  defp build_from_entry(conn, {status, slug, message}) do
    ProblemDetail.new(status)
    |> ProblemDetail.put_type("#{@type_base_url}/#{slug}")
    |> ProblemDetail.put_detail(Gettext.dgettext(DrinkWaterWeb.Gettext, "errors", message))
    |> ProblemDetail.put_instance(request_uri(conn))
  end

  defp request_uri(conn) do
    base = "#{conn.scheme}://#{conn.host}:#{conn.port}#{conn.request_path}"
    uri = URI.new!(base)

    case conn.query_string do
      "" -> URI.to_string(uri)
      qs -> uri |> URI.append_query(qs) |> URI.to_string()
    end
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
