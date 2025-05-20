defmodule FaultyTower.Repo.Migrations.AddNtfyTopicToProject do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :ntfy, :string
    end
  end
end
