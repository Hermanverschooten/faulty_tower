defmodule FaultyTower.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      FaultyTowerWeb.Telemetry,
      FaultyTower.Repo,
      {DNSCluster, query: Application.get_env(:faulty_tower, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: FaultyTower.PubSub},
      # Run the migrations
      {Task, &migrate/0},
      {Phx2Ban, router: FaultyTowerWeb.Router},
      # Start a worker by calling: FaultyTower.Worker.start_link(arg)
      # {FaultyTower.Worker, arg},
      # Start to serve requests, typically the last entry
      FaultyTowerWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: FaultyTower.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FaultyTowerWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp migrate do
    if Application.get_env(:faulty_tower, :run_migrations, false) do
      FaultyTower.Release.migrate()
    end
  end
end
