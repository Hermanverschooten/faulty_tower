# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     FaultyTower.Repo.insert!(%FaultyTower.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

{:ok, org} = FaultyTower.Organization.insert("Test Organization")

{:ok, admin} =
  FaultyTower.User.insert(%{organizations: [org.id], email: "admin@example.org", admin: true})
