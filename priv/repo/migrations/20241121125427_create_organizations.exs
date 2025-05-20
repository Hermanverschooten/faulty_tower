defmodule FaultyTower.Repo.Migrations.CreateOrganizations do
  use Ecto.Migration

  def change do
    create table("organizations") do
      add :name, :string, null: false
    end

    create unique_index("organizations", [:name])
  end
end
