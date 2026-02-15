defmodule ComfycatEmbed.Inspector do
  @moduledoc """
  Plug that injects the Comfycat inspector script into HTML responses.

  The inspector enables users to click on elements in the preview iframe
  and send context (tag, selector, page, text) back to the parent frame
  via `postMessage`.

  Only injects into responses with `text/html` content type.
  """

  @behaviour Plug

  @script_tag ~s(<script src="/comfycat-inspector.js"></script>)

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    Plug.Conn.register_before_send(conn, &inject_script/1)
  end

  defp inject_script(conn) do
    content_type = Plug.Conn.get_resp_header(conn, "content-type")

    if html_response?(content_type) do
      body = to_string(conn.resp_body)

      case String.split(body, "</body>", parts: 2) do
        [before, after_body] ->
          %{conn | resp_body: before <> @script_tag <> "</body>" <> after_body}

        _no_match ->
          conn
      end
    else
      conn
    end
  end

  defp html_response?([]), do: false
  defp html_response?([type | _]), do: String.starts_with?(type, "text/html")
end
