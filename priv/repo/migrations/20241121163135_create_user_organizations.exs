defmodule FaultyTower.Repo.Migrations.CreateUserOrganizations do
  use Ecto.Migration

  def change do
    create table("users_organizations", primary_key: false) do
      add :user_id, references("users"), primary_key: true
      add :organization_id, references("organizations"), primary_key: true
    end
  end
end
