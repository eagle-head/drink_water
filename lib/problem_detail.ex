defmodule ProblemDetail do
  @moduledoc """
  RFC 9457 Problem Detail struct for HTTP API error responses.

  A generic, zero-dependency value type representing an RFC 9457 problem detail.
  Designed to be reusable across Elixir projects.

  See: https://www.rfc-editor.org/rfc/rfc9457
  """

  @type t :: %__MODULE__{
          status: pos_integer(),
          type: String.t() | nil,
          title: String.t() | nil,
          detail: String.t() | nil,
          instance: String.t() | nil,
          properties: map()
        }

  @enforce_keys [:status]
  defstruct [:type, :title, :status, :detail, :instance, properties: %{}]

  @spec new(pos_integer()) :: t()
  def new(status) when is_integer(status) and status > 0 do
    %__MODULE__{status: status, title: reason_phrase(status)}
  end

  @spec new(pos_integer(), keyword()) :: t()
  def new(status, opts) when is_integer(status) and status > 0 and is_list(opts) do
    %__MODULE__{
      status: status,
      type: Keyword.get(opts, :type),
      title: Keyword.get(opts, :title, reason_phrase(status)),
      detail: Keyword.get(opts, :detail),
      instance: Keyword.get(opts, :instance)
    }
  end

  defp reason_phrase(status) do
    Plug.Conn.Status.reason_phrase(status)
  rescue
    ArgumentError -> nil
  end

  @spec put_type(t(), String.t()) :: t()
  def put_type(%__MODULE__{} = pd, type) when is_binary(type), do: %{pd | type: type}

  @spec put_title(t(), String.t()) :: t()
  def put_title(%__MODULE__{} = pd, title) when is_binary(title), do: %{pd | title: title}

  @spec put_detail(t(), String.t()) :: t()
  def put_detail(%__MODULE__{} = pd, detail) when is_binary(detail), do: %{pd | detail: detail}

  @spec put_instance(t(), String.t()) :: t()
  def put_instance(%__MODULE__{} = pd, instance) when is_binary(instance),
    do: %{pd | instance: instance}

  @spec put_extension(t(), String.Chars.t(), term()) :: t()
  def put_extension(%__MODULE__{} = pd, key, value) do
    %{pd | properties: Map.put(pd.properties, to_string(key), value)}
  end

  defimpl JSON.Encoder do
    @standard_field_names ~w(type title status detail instance)

    def encode(%ProblemDetail{} = pd, encoder) do
      standard =
        %{"type" => pd.type || "about:blank", "status" => pd.status}
        |> put_non_nil("title", pd.title)
        |> put_non_nil("detail", pd.detail)
        |> put_non_nil("instance", pd.instance)

      pd.properties
      |> Map.drop(@standard_field_names)
      |> Map.merge(standard)
      |> encoder.(encoder)
    end

    defp put_non_nil(map, _key, nil), do: map
    defp put_non_nil(map, key, value), do: Map.put(map, key, value)
  end
end
