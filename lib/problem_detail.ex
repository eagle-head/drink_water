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

  @reason_phrases %{
    100 => "Continue",
    101 => "Switching Protocols",
    102 => "Processing",
    103 => "Early Hints",
    200 => "OK",
    201 => "Created",
    202 => "Accepted",
    203 => "Non-Authoritative Information",
    204 => "No Content",
    205 => "Reset Content",
    206 => "Partial Content",
    207 => "Multi-Status",
    208 => "Already Reported",
    226 => "IM Used",
    300 => "Multiple Choices",
    301 => "Moved Permanently",
    302 => "Found",
    303 => "See Other",
    304 => "Not Modified",
    305 => "Use Proxy",
    307 => "Temporary Redirect",
    308 => "Permanent Redirect",
    400 => "Bad Request",
    401 => "Unauthorized",
    402 => "Payment Required",
    403 => "Forbidden",
    404 => "Not Found",
    405 => "Method Not Allowed",
    406 => "Not Acceptable",
    407 => "Proxy Authentication Required",
    408 => "Request Timeout",
    409 => "Conflict",
    410 => "Gone",
    411 => "Length Required",
    412 => "Precondition Failed",
    413 => "Content Too Large",
    414 => "URI Too Long",
    415 => "Unsupported Media Type",
    416 => "Range Not Satisfiable",
    417 => "Expectation Failed",
    418 => "I'm a Teapot",
    421 => "Misdirected Request",
    422 => "Unprocessable Content",
    423 => "Locked",
    424 => "Failed Dependency",
    425 => "Too Early",
    426 => "Upgrade Required",
    428 => "Precondition Required",
    429 => "Too Many Requests",
    431 => "Request Header Fields Too Large",
    451 => "Unavailable For Legal Reasons",
    500 => "Internal Server Error",
    501 => "Not Implemented",
    502 => "Bad Gateway",
    503 => "Service Unavailable",
    504 => "Gateway Timeout",
    505 => "HTTP Version Not Supported",
    506 => "Variant Also Negotiates",
    507 => "Insufficient Storage",
    508 => "Loop Detected",
    510 => "Not Extended",
    511 => "Network Authentication Required"
  }

  @spec new(pos_integer()) :: t()
  def new(status) when is_integer(status) and status > 0 do
    %__MODULE__{status: status, title: Map.get(@reason_phrases, status)}
  end

  @spec new(pos_integer(), keyword()) :: t()
  def new(status, opts) when is_integer(status) and status > 0 and is_list(opts) do
    title = Keyword.get(opts, :title, Map.get(@reason_phrases, status))

    %__MODULE__{
      status: status,
      type: Keyword.get(opts, :type),
      title: title,
      detail: Keyword.get(opts, :detail),
      instance: Keyword.get(opts, :instance)
    }
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
end
