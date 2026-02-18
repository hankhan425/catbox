defmodule WorkspaceAgent.Router do
  @moduledoc """
  HTTP router for the workspace agent.

  Endpoints:
  - GET  /health      — readiness probe (no auth)
  - POST /exec        — execute a command, stream output via SSE
  - GET  /files       — read a file from disk
  - GET  /files/tree  — list files in a directory
  - PUT  /files       — write a file to disk
  """

  use Plug.Router

  require Logger

  plug Plug.Logger
  plug :fetch_query_params
  plug WorkspaceAgent.AuthPlug
  plug :match
  plug :dispatch

  get "/health" do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{status: "ok"}))
  end

  post "/exec" do
    {:ok, body, conn} = Plug.Conn.read_body(conn)

    case Jason.decode(body) do
      {:ok, params} ->
        WorkspaceAgent.ExecHandler.handle(conn, params)

      {:error, _} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(%{error: "invalid JSON"}))
    end
  end

  get "/files/tree" do
    path = conn.query_params["path"] || "/home/user/app"
    WorkspaceAgent.FileHandler.handle_tree(conn, path)
  end

  get "/files" do
    path = conn.query_params["path"]

    if is_nil(path) do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(400, Jason.encode!(%{error: "path query parameter is required"}))
    else
      WorkspaceAgent.FileHandler.handle_read(conn, path)
    end
  end

  put "/files" do
    path = conn.query_params["path"]
    mode = conn.query_params["mode"]

    if is_nil(path) do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(400, Jason.encode!(%{error: "path query parameter is required"}))
    else
      {:ok, body, conn} = Plug.Conn.read_body(conn, length: 10_000_000)
      WorkspaceAgent.FileHandler.handle(conn, path, body, mode)
    end
  end

  match _ do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(404, Jason.encode!(%{error: "not found"}))
  end
end
