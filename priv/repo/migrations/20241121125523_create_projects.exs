defmodule FaultyTower.Repo.Migrations.CreateProjects do
  use Ecto.Migration

  def change do
    create table("projects") do
      add :key, :uuid
      add :name, :string
      add :organization_id, references("organizations"), null: false
    end

    create index("projects", [:organization_id])
  end
end
