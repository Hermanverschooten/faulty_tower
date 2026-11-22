defmodule FaultyTower.Repo.Migrations.AddGitProviderToErrors do
  use Ecto.Migration

  def change do
    alter table(:errors) do
      add :git_provider, :string
    end
  end
end
