defmodule WorkspaceAgent.AuthPlug do
  @moduledoc """
  Plug that verifies Bearer token authentication against the AGENT_TOKEN env var.
  The /health endpoint is excluded from auth checks.
  """

  import Plug.Conn

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%{request_path: "/health"} = conn, _opts), do: conn

  def call(conn, _opts) do
    expected_token = System.get_env("AGENT_TOKEN")

    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] when token == expected_token and expected_token != nil ->
        conn

      _ ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, Jason.encode!(%{error: "unauthorized"}))
        |> halt()
    end
  end
end
