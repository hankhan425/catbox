defmodule ComfycatEmbed.AllowIframeTest do
  use ExUnit.Case, async: true
  import Plug.Test
  import Plug.Conn

  alias ComfycatEmbed.AllowIframe

  test "removes x-frame-options header" do
    conn =
      conn(:get, "/")
      |> put_resp_header("x-frame-options", "SAMEORIGIN")
      |> AllowIframe.call(AllowIframe.init([]))

    refute get_resp_header(conn, "x-frame-options") != []
  end

  test "sets content-security-policy to base-uri only" do
    conn =
      conn(:get, "/")
      |> AllowIframe.call(AllowIframe.init([]))

    assert get_resp_header(conn, "content-security-policy") == ["base-uri 'self'"]
  end

  test "overrides existing CSP with frame-ancestors" do
    conn =
      conn(:get, "/")
      |> put_resp_header("content-security-policy", "base-uri 'self'; frame-ancestors 'self'")
      |> AllowIframe.call(AllowIframe.init([]))

    assert get_resp_header(conn, "content-security-policy") == ["base-uri 'self'"]
  end
end
