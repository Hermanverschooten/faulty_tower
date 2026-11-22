defmodule FaultyTowerWeb.ErrorsLiveTest do
  use FaultyTowerWeb.ConnCase

  import Ecto.Query
  import Phoenix.LiveViewTest
  import FaultyTower.AuthenticationFixtures

  alias FaultyTower.{Organization, Project, Repo}

  setup %{conn: conn} do
    user = user_fixture()
    {:ok, org} = Organization.create("Acme Org")
    Repo.insert_all("users_organizations", [%{user_id: user.id, organization_id: org.id}])
    {:ok, project} = Project.create("Shop", org.id, "s")
    %{conn: log_in_user(conn, user), project: project}
  end

  defp insert_error(project, reason, status, hours_ago) do
    at = DateTime.add(DateTime.utc_now(), -hours_ago, :hour)

    error =
      Repo.insert!(%Schema.Error{
        project_id: project.id,
        status: status,
        kind: "RuntimeError",
        reason: reason,
        source_line: "12",
        source_function: "Elixir.Shop.Cart.add/2",
        fingerprint: Base.encode16(:crypto.strong_rand_bytes(8)),
        last_occurrence_at: at
      })

    Repo.insert!(%Schema.Occurrence{
      error_id: error.id,
      reason: reason,
      context: %{},
      stacktrace: %Schema.Stacktrace{}
    })

    error
  end

  defp seed(project) do
    insert_error(project, "open-old", :unresolved, 10)
    insert_error(project, "open-new", :unresolved, 1)
    insert_error(project, "done-one", :resolved, 5)
  end

  defp url_for(project, query \\ ""), do: "/project/#{project.key}#{query}"

  test "default view lists only unresolved errors, newest first", %{conn: conn, project: p} do
    seed(p)
    {:ok, view, html} = live(conn, url_for(p))
    assert html =~ "open-new"
    assert html =~ "open-old"
    refute html =~ "done-one"

    assert html |> :binary.match("open-new") |> elem(0) <
             html |> :binary.match("open-old") |> elem(0)

    assert has_element?(view, "h1", "Shop")
  end

  test "status=resolved and status=all list the right rows", %{conn: conn, project: p} do
    seed(p)
    {:ok, _v, html} = live(conn, url_for(p, "?status=resolved"))
    assert html =~ "done-one"
    refute html =~ "open-new"

    {:ok, view, html} = live(conn, url_for(p, "?status=all"))
    assert html =~ "done-one" and html =~ "open-new" and html =~ "open-old"
    assert has_element?(view, "#error-table .status-word", "unresolved")
    assert has_element?(view, "#error-table .status-word", "resolved")
    # sorted by last seen across statuses
    {a, _} = :binary.match(html, "open-new")
    {b, _} = :binary.match(html, "done-one")
    {c, _} = :binary.match(html, "open-old")
    assert a < b and b < c
  end

  test "unknown status falls back to unresolved", %{conn: conn, project: p} do
    seed(p)
    {:ok, _v, html} = live(conn, url_for(p, "?status=bogus"))
    assert html =~ "open-new"
    refute html =~ "done-one"
  end

  test "totals sentence has counts and the right links", %{conn: conn, project: p} do
    seed(p)
    {:ok, view, _} = live(conn, url_for(p))
    assert has_element?(view, "#totals", "3 errors · 2 unresolved · 1 resolved")
    assert has_element?(view, ~s(#totals a[href="#{url_for(p, "?status=all")}"]), "3 errors")

    assert has_element?(
             view,
             ~s(#totals a[href="#{url_for(p, "?status=resolved")}"]),
             "1 resolved"
           )

    refute has_element?(view, "#totals a", "unresolved")

    {:ok, view, _} = live(conn, url_for(p, "?status=resolved"))
    assert has_element?(view, ~s(#totals a[href="#{url_for(p)}"]), "2 unresolved")
    refute has_element?(view, "#totals a", "1 resolved")
  end

  test "singular error count", %{conn: conn, project: p} do
    insert_error(p, "only", :unresolved, 1)
    {:ok, view, _} = live(conn, url_for(p))
    assert has_element?(view, "#totals", "1 error · 1 unresolved · 0 resolved")
  end

  test "a refresh for a deleted error removes its row instead of crashing", %{
    conn: conn,
    project: p
  } do
    e = insert_error(p, "gone-soon", :unresolved, 1)
    insert_error(p, "stays", :unresolved, 2)
    {:ok, view, _} = live(conn, url_for(p))
    assert has_element?(view, "#errors-#{e.id}")

    Repo.delete_all(from o in Schema.Occurrence, where: o.error_id == ^e.id)
    Repo.delete!(e)
    send(view.pid, {:refresh, e.id})

    refute has_element?(view, "#errors-#{e.id}")
    assert has_element?(view, "#totals", "1 error · 1 unresolved · 0 resolved")
  end

  test "resolve keeps the row, shows status word and updates totals", %{conn: conn, project: p} do
    e = insert_error(p, "open-new", :unresolved, 1)
    insert_error(p, "other", :unresolved, 2)
    {:ok, view, _} = live(conn, url_for(p))
    refute has_element?(view, "#errors-#{e.id}", "resolved")

    view |> element("#errors-#{e.id} button", "Resolve") |> render_click()

    assert has_element?(view, "#errors-#{e.id}", "open-new")
    assert has_element?(view, "#errors-#{e.id} .status-word", "resolved")
    assert has_element?(view, "#errors-#{e.id} button", "Reopen")
    assert has_element?(view, "#totals", "2 errors · 1 unresolved · 1 resolved")
  end

  defp recur(error) do
    Repo.update_all(from(e in Schema.Error, where: e.id == ^error.id),
      set: [status: :unresolved, last_occurrence_at: DateTime.utc_now()]
    )
  end

  test "a recurring error moves to the top of the list", %{conn: conn, project: p} do
    old = insert_error(p, "open-old", :unresolved, 10)
    insert_error(p, "open-new", :unresolved, 1)
    {:ok, view, _} = live(conn, url_for(p))

    recur(old)
    send(view.pid, {:add, old.id})
    html = render(view)

    {a, _} = :binary.match(html, "open-old")
    {b, _} = :binary.match(html, "open-new")
    assert a < b
    assert html |> String.split("open-old") |> length() == 2
  end

  test "a recurring resolved error leaves the resolved list", %{conn: conn, project: p} do
    e = insert_error(p, "done-one", :resolved, 5)
    insert_error(p, "done-two", :resolved, 6)
    {:ok, view, _} = live(conn, url_for(p, "?status=resolved"))
    assert has_element?(view, "#errors-#{e.id}")

    recur(e)
    send(view.pid, {:add, e.id})

    refute has_element?(view, "#errors-#{e.id}")
    assert has_element?(view, "#totals", "1 unresolved · 1 resolved")
  end

  test "resolve counts the statuses once", %{conn: conn, project: p} do
    e = insert_error(p, "open-new", :unresolved, 1)
    {:ok, view, _} = live(conn, url_for(p))
    ref = make_ref()
    me = self()

    :telemetry.attach(
      ref,
      [:faulty_tower, :repo, :query],
      fn _, _, %{query: q}, _ -> send(me, {:q, q}) end,
      nil
    )

    on_exit(fn -> :telemetry.detach(ref) end)

    view |> element("#errors-#{e.id} button", "Resolve") |> render_click()
    # sync with the view so its own :refresh broadcast has been handled
    assert has_element?(view, "#totals", "1 resolved")
    {:messages, msgs} = Process.info(self(), :messages)

    counts =
      Enum.count(
        msgs,
        &(match?({:q, q} when is_binary(q), &1) and
            String.contains?(elem(&1, 1), "GROUP BY e0.\"status\""))
      )

    assert counts == 1
  end

  test "empty states per filter and API hint only with no errors at all", %{
    conn: conn,
    project: p
  } do
    {:ok, view, _} = live(conn, url_for(p))
    assert has_element?(view, "#empty", "No errors yet.")
    assert has_element?(view, "#api-hint", "Report errors with POST to")
    assert has_element?(view, "#api-hint code", "/api/report/#{p.key}")

    insert_error(p, "done", :resolved, 1)
    {:ok, view, _} = live(conn, url_for(p))
    assert has_element?(view, "#empty", "No unresolved errors.")
    refute has_element?(view, "#api-hint")

    {:ok, view, _} = live(conn, url_for(p, "?status=all"))
    refute has_element?(view, "#empty")

    {:ok, p2} = Project.create("Other", Repo.get!(Schema.Project, p.id).organization_id, "o")
    insert_error(p2, "x", :unresolved, 1)
    {:ok, view, _} = live(conn, url_for(p2, "?status=resolved"))
    assert has_element?(view, "#empty", "No resolved errors.")
    refute has_element?(view, "#api-hint")
  end

  test "an :add for an error deleted meanwhile is a no-op", %{conn: conn, project: p} do
    e = insert_error(p, "gone", :unresolved, 1)
    {:ok, view, _} = live(conn, url_for(p))
    Repo.delete_all(from(o in Schema.Occurrence, where: o.error_id == ^e.id))
    Repo.delete!(e)

    send(view.pid, {:add, e.id})
    assert render(view) =~ "totals"
  end

  describe "ids scoped to the project" do
    test "resolve and unresolve ignore a foreign error id", %{conn: conn, project: project} do
      {:ok, org_b} = Organization.create("Other Org")
      {:ok, project_b} = Project.create("Other", org_b.id, "o")
      foreign = insert_error(project_b, "foreign", :unresolved, 1)
      {:ok, lv, _html} = live(conn, ~p"/project/#{project.key}")

      render_click(lv, "resolve", %{"error_id" => to_string(foreign.id)})
      assert Repo.get!(Schema.Error, foreign.id).status == :unresolved

      Repo.update_all(from(e in Schema.Error, where: e.id == ^foreign.id),
        set: [status: :resolved]
      )

      render_click(lv, "unresolve", %{"error_id" => to_string(foreign.id)})
      assert Repo.get!(Schema.Error, foreign.id).status == :resolved
    end
  end
end
