defmodule WorkspaceAgent.Application do
  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    port = String.to_integer(System.get_env("AGENT_PORT") || "9090")

    children = [
      {Bandit, plug: WorkspaceAgent.Router, port: port}
    ]

    Logger.info("Workspace agent starting on port #{port}")

    opts = [strategy: :one_for_one, name: WorkspaceAgent.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
