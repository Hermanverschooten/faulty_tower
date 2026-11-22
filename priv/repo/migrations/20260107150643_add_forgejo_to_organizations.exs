defmodule FaultyTower.Repo.Migrations.AddForgejoToOrganizations do
  use Ecto.Migration

  def change do
    alter table(:organizations) do
      add :forgejo, :jsonb
    end
  end
end
