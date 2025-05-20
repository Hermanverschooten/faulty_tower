defmodule FaultyTower.Release do
  @moduledoc """
  Tasks to run migrations in production.
  """
  @app :faulty_tower

  @doc "Migrate to the latest version"
  @spec migrate :: list()
  def migrate do
    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  @doc "Rollback to the previous version"
  @spec rollback(Ecto.Repo.t(), String.t()) :: {:ok, any(), any()}
  def rollback(repo, version) do
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.load(@app)
    Application.fetch_env!(@app, :ecto_repos)
  end
end
