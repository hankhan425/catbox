defmodule WorkspaceAgent.ExecHandler do
  @moduledoc """
  Handles POST /exec requests — spawns a command and streams output as SSE events.

  Request body:
    {"cmd": "claude", "args": ["--print", ...], "dir": "/home/user/app", "env": {"KEY": "val"}}

  Response: text/event-stream
    data: {"type":"stdout","data":"line of output\\n"}
    data: {"type":"exit","code":0}

  Uses Erlang ports to spawn the process and capture output in real-time.
  Stdout and stderr are merged (stderr redirected to stdout) since we're
  streaming to a chat UI where the distinction doesn't matter.
  """

  import Plug.Conn

  require Logger

  @default_timeout 900_000

  def handle(conn, params) do
    cmd = params["cmd"]
    args = params["args"] || []
    dir = params["dir"] || System.get_env("HOME") || "/home/user"
    env = build_env(params["env"])

    unless cmd do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(400, Jason.encode!(%{error: "cmd is required"}))
    else
      Logger.info("Exec: #{cmd} #{Enum.join(args, " ")} in #{dir}")
      stream_exec(conn, cmd, args, dir, env)
    end
  end

  defp stream_exec(conn, cmd, args, dir, env) do
    conn =
      conn
      |> put_resp_content_type("text/event-stream")
      |> put_resp_header("cache-control", "no-cache")
      |> put_resp_header("x-accel-buffering", "no")
      |> send_chunked(200)

    # Build the shell command — redirect stderr to stdout for unified streaming
    shell_cmd = build_shell_command(cmd, args)

    port_opts = [
      :binary,
      :exit_status,
      :use_stdio,
      :stderr_to_stdout,
      {:cd, dir},
      {:env, env},
      {:args, ["-c", shell_cmd]}
    ]

    port = Port.open({:spawn_executable, shell_path()}, port_opts)

    stream_loop(conn, port, @default_timeout)
  end

  defp stream_loop(conn, port, timeout) do
    receive do
      {^port, {:data, data}} ->
        case send_sse_event(conn, %{type: "stdout", data: data}) do
          {:ok, conn} ->
            stream_loop(conn, port, timeout)

          {:error, _reason} ->
            # Client disconnected — kill the process
            Port.close(port)
            conn
        end

      {^port, {:exit_status, code}} ->
        {:ok, conn} = send_sse_event(conn, %{type: "exit", code: code})
        conn
    after
      timeout ->
        Logger.warning("Exec timed out after #{timeout}ms")
        Port.close(port)
        {:ok, conn} = send_sse_event(conn, %{type: "exit", code: 124})
        conn
    end
  end

  defp send_sse_event(conn, event) do
    data = "data: #{Jason.encode!(event)}\n\n"
    chunk(conn, data)
  end

  defp build_shell_command(cmd, args) do
    # Escape each argument for shell safety
    escaped_args = Enum.map(args, &shell_escape/1)
    inner = Enum.join([shell_escape(cmd) | escaped_args], " ")

    # Force unbuffered stdout so output streams in real-time through the port.
    # Node.js fully buffers stdout when piped (not a TTY), so stdbuf alone
    # doesn't work. `unbuffer` (from expect) allocates a pseudo-TTY, which
    # makes Node.js use line buffering. Falls back to stdbuf, then raw.
    cond do
      unbuffer_available?() -> "unbuffer #{inner}"
      stdbuf_available?() -> "stdbuf -oL #{inner}"
      true -> inner
    end
  end

  defp unbuffer_available? do
    System.find_executable("unbuffer") != nil
  end

  defp stdbuf_available? do
    System.find_executable("stdbuf") != nil
  end

  defp shell_escape(arg) do
    # Single-quote the argument, escaping any existing single quotes
    "'" <> String.replace(arg, "'", "'\\''") <> "'"
  end

  defp shell_path do
    System.find_executable("bash") || System.find_executable("sh") || "/bin/sh"
  end

  defp build_env(nil), do: []

  defp build_env(env_map) when is_map(env_map) do
    Enum.map(env_map, fn {k, v} -> {String.to_charlist(k), String.to_charlist(to_string(v))} end)
  end

  defp build_env(_), do: []
end
