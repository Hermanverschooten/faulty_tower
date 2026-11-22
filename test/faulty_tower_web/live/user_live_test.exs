defmodule FaultyTowerWeb.UserLiveTest do
  use FaultyTowerWeb.ConnCase

  import Phoenix.LiveViewTest
  import FaultyTower.AuthenticationFixtures

  alias FaultyTower.Repo

  defp make_admin(user), do: user |> Ecto.Changeset.change(admin: true) |> Repo.update!()

  defp setup_admin(%{conn: conn}) do
    admin = user_fixture(%{email: "mid@example.com"}) |> make_admin()
    %{conn: log_in_user(conn, admin), admin: admin}
  end

  setup :setup_admin

  test "lists users by email with orgs and admin word", %{conn: conn, admin: admin} do
    {:ok, org_a} = FaultyTower.Organization.insert(%{name: "Acme Corp"})
    {:ok, org_b} = FaultyTower.Organization.insert(%{name: "Globex"})
    zed = user_fixture(%{email: "zed@example.com"})
    amy = user_fixture(%{email: "amy@example.com"})

    FaultyTower.User.update(Repo.preload(admin, :organizations), %{
      "email" => admin.email,
      "admin" => "true",
      "organizations" => [org_a.id, org_b.id]
    })

    FaultyTower.User.update(Repo.preload(amy, :organizations), %{
      "email" => amy.email,
      "organizations" => [org_a.id]
    })

    {:ok, view, _} = live(conn, ~p"/users")
    html = view |> element("#users") |> render()

    {a, m, z} = {
      :binary.match(html, "amy@example.com"),
      :binary.match(html, "mid@example.com"),
      :binary.match(html, "zed@example.com")
    }

    assert elem(a, 0) < elem(m, 0)
    assert elem(m, 0) < elem(z, 0)

    assert view |> element("#users-#{admin.id}") |> render() =~ "Acme Corp"
    assert view |> element("#users-#{admin.id}") |> render() =~ "Globex"
    assert view |> element("#users-#{admin.id}") |> render() =~ "admin"
    assert view |> element("#users-#{amy.id}") |> render() =~ "Acme Corp"
    refute view |> element("#users-#{amy.id}") |> render() =~ "admin"
    refute view |> element("#users-#{zed.id}") |> render() =~ "admin"
  end

  test "the users table header names the first column Email", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/users")
    assert view |> element("#users > div:first-child > span:first-child") |> render() =~ "Email"
  end

  test "clicking a row opens the edit form and Cancel closes it", %{conn: conn, admin: admin} do
    {:ok, view, _} = live(conn, ~p"/users")
    refute has_element?(view, "#user_edit_form")

    view |> element("#users-#{admin.id}") |> render_click()
    assert view |> element("#user_edit_form") |> render() =~ "mid@example.com"

    view |> element("#user_edit button", "Cancel") |> render_click()
    refute has_element?(view, "#user_edit_form")
  end

  test "adding a user shows the new row with its organization", %{conn: conn} do
    {:ok, org} = FaultyTower.Organization.insert(%{name: "Initech"})
    {:ok, view, _} = live(conn, ~p"/users")

    view |> element("button", "Add user") |> render_click()

    view
    |> form("#user_edit_form", %{
      "user" => %{
        "email" => "new@example.com",
        "organizations" => [to_string(org.id)],
        "send_welcome_email" => "false"
      }
    })
    |> render_submit()

    new = Repo.get_by!(FaultyTower.Authentication.User, email: "new@example.com")
    assert view |> element("#users-#{new.id}") |> render() =~ "Initech"
  end

  test "adding a user with an existing email shows an error", %{conn: conn, admin: admin} do
    {:ok, view, _html} = live(conn, ~p"/users")
    view |> element("button", "Add user") |> render_click()

    html =
      view
      |> form("#user_edit_form", %{
        "user" => %{"email" => admin.email, "send_welcome_email" => "false"}
      })
      |> render_submit()

    assert html =~ "has already been taken"
  end

  test "non-admin is redirected", %{conn: conn} do
    user = user_fixture()
    assert {:error, {:redirect, _}} = live(log_in_user(conn, user), ~p"/users")
  end
end
