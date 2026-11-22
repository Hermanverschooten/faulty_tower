Mimic.copy(FaultyTower.Recorder)
Mimic.copy(FaultyTower.Forgejo)
Mimic.copy(FaultyTower.Github)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(FaultyTower.Repo, :manual)
