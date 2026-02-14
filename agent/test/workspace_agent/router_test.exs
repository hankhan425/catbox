defmodule WorkspaceAgent.RouterTest do
  use ExUnit.Case, async: true

  import Plug.Test
  import Plug.Conn

  @token "test-secret-token"

  setup do
    System.put_env("AGENT_TOKEN", @token)
    on_exit(fn -> System.delete_env("AGENT_TOKEN") end)
    :ok
  end

  defp call(conn) do
    WorkspaceAgent.Router.call(conn, WorkspaceAgent.Router.init([]))
  end

  defp authed_conn(method, path, body \\ nil) do
    conn = conn(method, path, body)
    put_req_header(conn, "authorization", "Bearer #{@token}")
  end

  describe "GET /health" do
    test "returns 200 without auth" do
      conn = conn(:get, "/health") |> call()

      assert conn.status == 200
      assert Jason.decode!(conn.resp_body) == %{"status" => "ok"}
    end
  end

  describe "authentication" do
    test "rejects request without token" do
      conn =
        conn(:post, "/exec", Jason.encode!(%{cmd: "echo", args: ["hi"]}))
        |> put_req_header("content-type", "application/json")
        |> call()

      assert conn.status == 401
    end

    test "rejects request with wrong token" do
      conn =
        conn(:post, "/exec", Jason.encode!(%{cmd: "echo", args: ["hi"]}))
        |> put_req_header("content-type", "application/json")
        |> put_req_header("authorization", "Bearer wrong-token")
        |> call()

      assert conn.status == 401
    end

    test "accepts request with correct token" do
      conn =
        conn(:post, "/exec", Jason.encode!(%{cmd: "echo", args: ["hi"]}))
        |> put_req_header("content-type", "application/json")
        |> put_req_header("authorization", "Bearer #{@token}")
        |> call()

      assert conn.status == 200
    end
  end

  describe "POST /exec" do
    test "executes a command and streams SSE output" do
      conn =
        authed_conn(:post, "/exec", Jason.encode!(%{cmd: "echo", args: ["hello world"]}))
        |> put_req_header("content-type", "application/json")
        |> call()

      assert conn.status == 200
      assert {"content-type", "text/event-stream; charset=utf-8"} in conn.resp_headers

      events = parse_sse_events(conn.resp_body)

      stdout_events = Enum.filter(events, &(&1["type"] == "stdout"))
      exit_events = Enum.filter(events, &(&1["type"] == "exit"))

      assert length(exit_events) == 1
      assert hd(exit_events)["code"] == 0

      combined_output = Enum.map_join(stdout_events, "", & &1["data"])
      assert combined_output =~ "hello world"
    end

    test "returns non-zero exit code for failed commands" do
      conn =
        authed_conn(:post, "/exec", Jason.encode!(%{cmd: "bash", args: ["-c", "exit 42"]}))
        |> put_req_header("content-type", "application/json")
        |> call()

      assert conn.status == 200
      events = parse_sse_events(conn.resp_body)

      exit_event = Enum.find(events, &(&1["type"] == "exit"))
      assert exit_event["code"] == 42
    end

    test "returns 400 for missing cmd" do
      conn =
        authed_conn(:post, "/exec", Jason.encode!(%{args: ["hello"]}))
        |> put_req_header("content-type", "application/json")
        |> call()

      assert conn.status == 400
    end

    test "returns 400 for invalid JSON" do
      conn =
        authed_conn(:post, "/exec", "not json")
        |> put_req_header("content-type", "application/json")
        |> call()

      assert conn.status == 400
    end

    test "passes environment variables to the command" do
      conn =
        authed_conn(:post, "/exec", Jason.encode!(%{
          cmd: "bash",
          args: ["-c", "echo $MY_VAR"],
          env: %{"MY_VAR" => "test_value"}
        }))
        |> put_req_header("content-type", "application/json")
        |> call()

      events = parse_sse_events(conn.resp_body)

      combined_output =
        events
        |> Enum.filter(&(&1["type"] == "stdout"))
        |> Enum.map_join("", & &1["data"])

      assert combined_output =~ "test_value"
    end

    test "respects working directory" do
      # Use /tmp which is a real path on all platforms (avoids macOS /var → /private/var symlink)
      dir = "/tmp"

      conn =
        authed_conn(:post, "/exec", Jason.encode!(%{
          cmd: "pwd",
          args: [],
          dir: dir
        }))
        |> put_req_header("content-type", "application/json")
        |> call()

      events = parse_sse_events(conn.resp_body)

      combined_output =
        events
        |> Enum.filter(&(&1["type"] == "stdout"))
        |> Enum.map_join("", & &1["data"])

      assert String.trim(combined_output) =~ "tmp"
    end
  end

  describe "PUT /files" do
    test "writes a file to disk" do
      path = Path.join(System.tmp_dir!(), "workspace_test_#{:rand.uniform(100_000)}.txt")
      on_exit(fn -> File.rm(path) end)

      conn =
        authed_conn(:put, "/files?path=#{URI.encode(path)}&mode=644", "hello file content")
        |> call()

      assert conn.status == 200
      assert File.read!(path) == "hello file content"
    end

    test "creates parent directories" do
      dir = Path.join(System.tmp_dir!(), "workspace_test_#{:rand.uniform(100_000)}")
      path = Path.join(dir, "sub/deep/file.txt")
      on_exit(fn -> File.rm_rf(dir) end)

      conn =
        authed_conn(:put, "/files?path=#{URI.encode(path)}", "nested content")
        |> call()

      assert conn.status == 200
      assert File.read!(path) == "nested content"
    end

    test "returns 400 without path parameter" do
      conn = authed_conn(:put, "/files", "content") |> call()
      assert conn.status == 400
    end
  end

  describe "unknown routes" do
    test "returns 404" do
      conn = authed_conn(:get, "/unknown") |> call()
      assert conn.status == 404
    end
  end

  # Helpers

  defp parse_sse_events(body) when is_binary(body) do
    body
    |> String.split("\n")
    |> Enum.filter(&String.starts_with?(&1, "data: "))
    |> Enum.map(fn "data: " <> json ->
      case Jason.decode(json) do
        {:ok, event} -> event
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_sse_events(_), do: []
end
