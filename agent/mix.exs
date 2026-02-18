defmodule WorkspaceAgent.MixProject do
  use Mix.Project

  def project do
    [
      app: :workspace_agent,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {WorkspaceAgent.Application, []}
    ]
  end

  defp deps do
    [
      {:bandit, "~> 1.0"},
      {:websock_adapter, "~> 0.5"},
      {:plug, "~> 1.16"},
      {:jason, "~> 1.4"}
    ]
  end
end
