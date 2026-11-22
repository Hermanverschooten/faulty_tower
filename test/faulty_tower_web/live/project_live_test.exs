defmodule FaultyTowerWeb.ProjectLiveTest do
  use FaultyTowerWeb.ConnCase

  import Phoenix.LiveViewTest
  import FaultyTower.AuthenticationFixtures

  alias FaultyTower.{Organization, Project, Repo}

  setup %{conn: conn} do
    user = user_fixture()
    {:ok, org} = Organization.create("Acme Org")
    Repo.insert_all("users_organizations", [%{user_id: user.id, organization_id: org.id}])
    {:ok, project} = Project.create("Shop", org.id, "s")
    %{conn: log_in_user(conn, user), project: project, org: org}
  end

  describe "edit" do
    test "Cancel links to the project's error list", %{conn: conn, project: project} do
      {:ok, lv, _html} = live(conn, ~p"/project/#{project.id}/edit")

      assert has_element?(lv, ~s(a[href="/project/#{project.key}"]), "Cancel")
      assert has_element?(lv, "h1", "Edit project")
    end

    test "Delete project opens the confirm modal", %{conn: conn, project: project} do
      {:ok, lv, _html} = live(conn, ~p"/project/#{project.id}/edit")

      refute has_element?(lv, "#confirm-delete")
      lv |> element("button", "Delete project") |> render_click()
      assert has_element?(lv, "#confirm-delete")
    end

    test "blank name renders the error", %{conn: conn, project: project} do
      {:ok, lv, _html} = live(conn, ~p"/project/#{project.id}/edit")

      html =
        lv
        |> form("#edit-project-form", project: %{name: ""})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end
  end

  describe "new" do
    setup %{conn: conn} do
      admin = user_fixture() |> Ecto.Changeset.change(admin: true) |> Repo.update!()
      %{conn: log_in_user(conn, admin)}
    end

    test "Cancel links to /organizations", %{conn: conn, org: org} do
      {:ok, lv, _html} = live(conn, ~p"/project/#{org.id}/new")

      assert has_element?(lv, ~s(a[href="/organizations"]), "Cancel")
      assert has_element?(lv, "h1", "New project")
    end

    test "blank name renders the error", %{conn: conn, org: org} do
      {:ok, lv, _html} = live(conn, ~p"/project/#{org.id}/new")

      html =
        lv
        |> form("#new-project-form", project: %{name: ""})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end
  end

  describe "access" do
    setup %{conn: conn} do
      {:ok, other_org} = Organization.create("Other Org")
      {:ok, other} = Project.create("Secret", other_org.id, "x")
      outsider = user_fixture()
      admin = user_fixture() |> Ecto.Changeset.change(admin: true) |> Repo.update!()

      %{
        other: other,
        other_org: other_org,
        outsider_conn: log_in_user(conn, outsider),
        admin_conn: log_in_user(conn, admin)
      }
    end

    test "edit: non-member is redirected with Project not found", %{
      outsider_conn: conn,
      project: project
    } do
      assert {:error, {:live_redirect, %{to: "/", flash: flash}}} =
               live(conn, ~p"/project/#{project.id}/edit")

      assert flash["error"] == "Project not found"
    end

    test "edit: member gets the page", %{conn: conn, project: project} do
      assert {:ok, _lv, _html} = live(conn, ~p"/project/#{project.id}/edit")
    end

    test "edit: admin who is not a member gets the page", %{admin_conn: conn, other: other} do
      assert {:ok, _lv, _html} = live(conn, ~p"/project/#{other.id}/edit")
    end

    test "edit: member cannot move the project to another organization", %{
      conn: conn,
      project: project,
      org: org,
      other_org: other_org
    } do
      {:ok, lv, _html} = live(conn, ~p"/project/#{project.id}/edit")
      refute has_element?(lv, "select#project_organization_id")

      render_submit(lv, "save", %{
        "project" => %{"name" => "Renamed", "organization_id" => other_org.id}
      })

      reloaded = Repo.get!(Schema.Project, project.id)
      assert reloaded.name == "Renamed"
      assert reloaded.organization_id == org.id
    end

    test "edit: admin can move the project", %{
      admin_conn: conn,
      project: project,
      other_org: other_org
    } do
      {:ok, lv, _html} = live(conn, ~p"/project/#{project.id}/edit")

      lv
      |> form("#edit-project-form", project: %{organization_id: other_org.id})
      |> render_submit()

      assert Repo.get!(Schema.Project, project.id).organization_id == other_org.id
    end

    test "new: non-admin member is redirected", %{conn: conn, org: org} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/project/#{org.id}/new")
    end
  end
end
