defmodule FaultyTower.Repo.Migrations.AddGhIssue do
  use Ecto.Migration

  def change do
    alter table(:errors) do
      add :gh_issue, :integer
    end
  end
end
