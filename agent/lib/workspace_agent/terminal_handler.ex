defmodule WorkspaceAgent.TerminalHandler do
  @moduledoc """
  WebSocket handler that provides interactive PTY terminal sessions.

  Uses the `script` command to allocate a real PTY without native dependencies.
  Receives binary frames as stdin input and sends binary frames as stdout output.
  Accepts JSON text frames for resize events.
  """

  @behaviour WebSock

  require Logger

  @impl true
  def init(opts) do
    shell_cmd = ~c"script -qfc bash /dev/null"

    port =
      Port.open({:spawn, shell_cmd}, [
        :binary,
        :exit_status,
        :use_stdio,
        :stderr_to_stdout,
        {:env, [{~c"TERM", ~c"xterm-256color"}]}
      ])

    Logger.info("Terminal session started (token: #{String.slice(opts[:token] || "", 0..7)}...)")
    {:ok, %{port: port}}
  end

  @impl true
  def handle_in({data, [opcode: :binary]}, state) do
    Port.command(state.port, data)
    {:ok, state}
  end

  def handle_in({data, [opcode: :text]}, state) do
    case Jason.decode(data) do
      {:ok, %{"type" => "resize", "cols" => cols, "rows" => rows}}
      when is_integer(cols) and is_integer(rows) ->
        # Use stty to resize the PTY
        resize_cmd = "stty cols #{cols} rows #{rows}\n"
        Port.command(state.port, resize_cmd)
        {:ok, state}

      _ ->
        {:ok, state}
    end
  end

  @impl true
  def handle_info({port, {:data, data}}, %{port: port} = state) do
    {:push, {:binary, data}, state}
  end

  def handle_info({port, {:exit_status, code}}, %{port: port} = state) do
    Logger.info("Terminal PTY exited with code #{code}")
    {:stop, :normal, state}
  end

  def handle_info(_msg, state) do
    {:ok, state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("Terminal session ending: #{inspect(reason)}")

    if is_port(state.port) and Port.info(state.port) != nil do
      Port.close(state.port)
    end

    :ok
  end
end
