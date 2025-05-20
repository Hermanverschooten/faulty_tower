defmodule FaultyTower.Dashboard do
  alias FaultyTower.Repo

  def projects(user) do
    Repo.preload(user, projects: [:organization, :unresolved_errors])
  end
end
