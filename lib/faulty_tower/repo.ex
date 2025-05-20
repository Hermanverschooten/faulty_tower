defmodule FaultyTower.Repo do
  use Ecto.Repo,
    otp_app: :faulty_tower,
    adapter: Ecto.Adapters.Postgres
end
