defmodule FaultyTowerWeb.OrganizationLiveEditTest do
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

  test "edit page has a back link, h1 and Cancel to /organizations", %{conn: conn} do
    {:ok, org} = FaultyTower.Organization.create("Acme Corp")
    {:ok, view, _} = live(conn, ~p"/organizations/#{org.id}/edit")

    assert has_element?(view, ~s(a[href="/organizations"]), "Organizations")
    assert has_element?(view, "h1", "Edit organization")
    assert has_element?(view, ~s(a[href="/organizations"]), "Cancel")
  end

  test "new page has a back link, h1 and Cancel to /organizations", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/organizations/new")

    assert has_element?(view, ~s(a[href="/organizations"]), "Organizations")
    assert has_element?(view, "h1", "New organization")
    assert has_element?(view, ~s(a[href="/organizations"]), "Cancel")
  end

  test "a blank name shows an error", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/organizations/new")

    html =
      view
      |> form("#organization_edit_form", organization: %{name: ""})
      |> render_submit()

    assert html =~ "can&#39;t be blank"
  end
end
