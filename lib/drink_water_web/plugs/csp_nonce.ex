defmodule DrinkWaterWeb.Plugs.CspNonce do
  @moduledoc """
  Generates a per-request CSP nonce and sets the Content-Security-Policy header.

  The nonce is stored in `conn.assigns.csp_nonce` and can be used in templates
  via `@csp_nonce`. A `<meta name="csp-nonce">` tag in the root layout makes
  the nonce available to JavaScript.

  ## Policy

  The default policy uses `nonce` + `strict-dynamic` (CSP Level 3):

    - Scripts only execute if they carry the correct nonce
    - `strict-dynamic` propagates trust to scripts loaded dynamically
    - `style-src 'unsafe-inline'` is required for LiveView and Tailwind/DaisyUI
    - `object-src 'none'` blocks Flash/Java applets
    - `form-action 'self'` prevents form hijacking

  ## Enforcement

  The policy is set as `content-security-policy` (enforcing) by default.
  To switch to report-only mode during migration, change the header name
  to `content-security-policy-report-only`.

  When enforcing, this plug replaces the default CSP from
  `put_secure_browser_headers` (since it runs after it in the pipeline).

  ## Compatibility

  Works out of the box with LiveView, DaisyUI, Stimulus, and modern
  JS frameworks (React, Vue, Svelte).

  Adjustments needed for specific libraries:

    * Alpine.js: add `'unsafe-eval'` to `script-src`
    * Flowbite (inline handlers): add `'unsafe-hashes'` to `script-src`

  """

  import Plug.Conn

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    nonce = generate_nonce()

    conn
    |> assign(:csp_nonce, nonce)
    |> put_resp_header("content-security-policy", policy(nonce))
  end

  defp generate_nonce do
    16
    |> :crypto.strong_rand_bytes()
    |> Base.encode64(padding: false)
  end

  defp policy(nonce) do
    [
      "default-src 'self'",
      "script-src 'nonce-#{nonce}' 'strict-dynamic'",
      "style-src 'self' 'unsafe-inline'",
      "img-src 'self' data:",
      "font-src 'self'",
      "connect-src 'self' ws: wss:",
      "object-src 'none'",
      "form-action 'self'",
      "base-uri 'self'",
      "frame-ancestors 'self'"
    ]
    |> Enum.join("; ")
  end
end
