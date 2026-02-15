defmodule ComfycatEmbed.AllowIframe do
  @moduledoc """
  Plug that strips frame-blocking headers so the app can be embedded
  in the Comfycat preview iframe (cross-origin).

  Removes `x-frame-options` and overrides the CSP to omit `frame-ancestors`.
  """

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    conn
    |> Plug.Conn.delete_resp_header("x-frame-options")
    |> Plug.Conn.put_resp_header("content-security-policy", "base-uri 'self'")
  end
end
