defmodule FaultyTower.Repo.Migrations.AddOtpAppToProject do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :otp_app, :string
    end
  end
end
