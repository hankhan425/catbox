defmodule ComfycatEmbed.InspectorTest do
  use ExUnit.Case, async: true
  import Plug.Test
  import Plug.Conn

  alias ComfycatEmbed.Inspector

  defp call_with_response(conn, status, headers, body) do
    conn = Inspector.call(conn, Inspector.init([]))

    Enum.reduce(headers, conn, fn {k, v}, c ->
      put_resp_header(c, k, v)
    end)
    |> resp(status, body)
    |> send_resp()
  end

  test "injects script before </body> in HTML responses" do
    conn =
      conn(:get, "/")
      |> call_with_response(200, [{"content-type", "text/html; charset=utf-8"}], "<html><body><p>Hello</p></body></html>")

    assert conn.resp_body =~ "<script>(function"
    assert conn.resp_body =~ "comfycat:start-inspect"
    assert conn.resp_body =~ "</script></body>"
    assert conn.resp_body =~ "<p>Hello</p>"
  end

  test "does not inject into non-HTML responses" do
    conn =
      conn(:get, "/api/data")
      |> call_with_response(200, [{"content-type", "application/json"}], ~s({"ok": true}))

    refute conn.resp_body =~ "comfycat:start-inspect"
  end

  test "does not inject when no </body> tag present" do
    conn =
      conn(:get, "/fragment")
      |> call_with_response(200, [{"content-type", "text/html"}], "<div>fragment</div>")

    assert conn.resp_body == "<div>fragment</div>"
  end

  test "handles responses with no content-type" do
    conn =
      conn(:get, "/")
      |> Inspector.call(Inspector.init([]))
      |> resp(204, "")
      |> send_resp()

    assert conn.status == 204
  end
end
