defmodule FaultyTower.Repo.Migrations.AddForgejoToProjects do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :forgejo, :jsonb
    end
  end
end
