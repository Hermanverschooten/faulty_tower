defmodule FaultyTower.Repo.Migrations.RenameGithubToRepositoryAndAddGitProvider do
  use Ecto.Migration

  def up do
    rename table(:projects), :github, to: :repository

    alter table(:projects) do
      add :git_provider, :string
      remove :forgejo
    end

    execute("UPDATE projects SET git_provider = 'github' WHERE repository IS NOT NULL")
  end

  def down do
    execute("UPDATE projects SET git_provider = NULL")

    alter table(:projects) do
      remove :git_provider
      add :forgejo, :jsonb
    end

    rename table(:projects), :repository, to: :github
  end
end
