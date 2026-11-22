defmodule FaultyTowerWeb.OrganizationLiveIndexTest do
  use FaultyTowerWeb.ConnCase

  import Phoenix.LiveViewTest
  import FaultyTower.AuthenticationFixtures

  alias FaultyTower.Repo

  setup %{conn: conn} do
    admin =
      user_fixture(%{email: "mid@example.com"})
      |> Ecto.Changeset.change(admin: true)
      |> Repo.update!()

    %{conn: log_in_user(conn, admin)}
  end

  test "groups projects under their organization", %{conn: conn} do
    {:ok, acme} = FaultyTower.Organization.create("Acme Corp")
    {:ok, empty} = FaultyTower.Organization.create("Zed Empty")
    {:ok, p1} = FaultyTower.Project.create("Alpha", acme.id, "alpha_app")
    {:ok, p2} = FaultyTower.Project.create("Beta", acme.id, "beta_app")

    {:ok, view, _} = live(conn, ~p"/organizations")

    org = view |> element("#org-#{acme.id}") |> render()
    assert org =~ "Acme Corp"
    assert org =~ ~s(href="/organizations/#{acme.id}/edit")
    assert org =~ ~s(href="/project/#{acme.id}/new")
    assert org =~ "Edit"
    assert org =~ "Add project"

    row1 = view |> element("#project-#{p1.id}") |> render()
    assert row1 =~ "Alpha"
    assert row1 =~ "alpha_app"
    assert row1 =~ ~s(href="/project/#{p1.id}/edit")

    row2 = view |> element("#project-#{p2.id}") |> render()
    assert row2 =~ "beta_app"

    assert view |> element("#org-#{empty.id}") |> render() =~ "Zed Empty"
    assert view |> element("#org-#{empty.id}-empty") |> render() =~ "No projects"
    refute has_element?(view, "#org-#{acme.id}-empty")
  end

  test "has a New organization link", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/organizations")

    assert view |> element(~s(a[href="/organizations/new"]), "New organization") |> has_element?()
  end
end
