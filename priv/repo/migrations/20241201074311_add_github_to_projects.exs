defmodule FaultyTower.Repo.Migrations.AddGithubToProjects do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :github, :jsonb
    end
  end
end
