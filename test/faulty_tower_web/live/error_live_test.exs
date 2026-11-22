defmodule FaultyTowerWeb.ErrorLiveTest do
  use FaultyTowerWeb.ConnCase
  use Mimic

  import Phoenix.LiveViewTest
  import Ecto.Query
  import FaultyTower.AuthenticationFixtures

  alias FaultyTower.{Forgejo, Github, Organization, Project, Repo}

  setup %{conn: conn} do
    user = user_fixture()
    {:ok, org} = Organization.create("Acme Org")
    Repo.insert_all("users_organizations", [%{user_id: user.id, organization_id: org.id}])
    {:ok, project} = Project.create("Shop", org.id, "s")
    project = project |> Ecto.Changeset.change(otp_app: "shop") |> Repo.update!()
    %{conn: log_in_user(conn, user), project: project}
  end

  defp insert_error(project, attrs \\ %{}) do
    Repo.insert!(
      struct(
        %Schema.Error{
          project_id: project.id,
          status: :unresolved,
          kind: "Elixir.RuntimeError",
          reason: "boom happened",
          source_line: "12",
          source_function: "Elixir.Shop.Cart.add/2",
          fingerprint: Base.encode16(:crypto.strong_rand_bytes(8)),
          last_occurrence_at: DateTime.utc_now()
        },
        attrs
      )
    )
  end

  defp insert_occurrence(error, reason \\ "occ", lines \\ []) do
    Repo.insert!(%Schema.Occurrence{
      error_id: error.id,
      reason: reason,
      context: %{"user" => 1},
      stacktrace: %Schema.Stacktrace{lines: lines}
    })
  end

  defp err_path(project, error, occ \\ nil),
    do: "/project/#{project.key}/#{error.id}" <> if(occ, do: "/#{occ.id}", else: "")

  test "occurrence queries run once per navigation, not again in mount", %{
    conn: conn,
    project: p
  } do
    error = insert_error(p)
    insert_occurrence(error)
    me = self()
    ref = make_ref()

    :telemetry.attach(
      ref,
      [:faulty_tower, :repo, :query],
      fn _, _, %{query: q}, _ -> send(me, {:q, q}) end,
      nil
    )

    on_exit(fn -> :telemetry.detach(ref) end)

    {:ok, _view, _} = live(conn, err_path(p, error))
    {:messages, msgs} = Process.info(self(), :messages)
    # one dead render plus one connected render, each loading once
    assert Enum.count(msgs, &match?({:q, "SELECT max(" <> _}, &1)) == 2
  end

  test "message and source carry no template whitespace (they render pre-wrapped)", %{
    conn: conn,
    project: p
  } do
    e = insert_error(p)
    insert_occurrence(e, "full message")
    {:ok, view, _} = live(conn, err_path(p, e))

    html = render(view)
    assert html =~ ~r{id="message"[^>]*>full message</pre>}
    assert html =~ ~r{id="source"[^>]*>Shop.Cart.add/2 12</pre>}
  end

  describe "header" do
    test "shows breadcrumb, full reason, kind and id, status and no old chrome", %{
      conn: conn,
      project: p
    } do
      e = insert_error(p)
      insert_occurrence(e)
      {:ok, view, html} = live(conn, err_path(p, e))

      assert has_element?(view, ~s(a[href="/project/#{p.key}"]), "Acme Org / Shop")
      assert has_element?(view, "h1", "boom happened")
      assert html =~ "RuntimeError · ##{e.id}"
      assert has_element?(view, "#error-header .text-red-700", "unresolved")
      refute html =~ "Back to list"
      refute has_element?(view, "select")
    end

    test "resolve and reopen flip the status word and button", %{conn: conn, project: p} do
      e = insert_error(p)
      insert_occurrence(e)
      {:ok, view, _} = live(conn, err_path(p, e))

      view |> element("button", "Resolve") |> render_click()
      assert has_element?(view, "#error-header .text-emerald-700\\/70", "resolved")
      assert has_element?(view, "button", "Reopen")

      view |> element("button", "Reopen") |> render_click()
      assert has_element?(view, "#error-header .text-red-700", "unresolved")
    end

    test "first and last seen use the exact time format", %{conn: conn, project: p} do
      e = insert_error(p, %{last_occurrence_at: ~U[2026-11-21 09:12:00.000000Z]})
      insert_occurrence(e)
      {:ok, view, _} = live(conn, err_path(p, e))

      assert has_element?(
               view,
               ~s(time[data-format="exact"][phx-hook="LocalTime"]),
               "21 Nov 2026, 09:12 UTC"
             )
    end
  end

  describe "relative_time component" do
    import Phoenix.Component
    import FaultyTowerWeb.CoreComponents

    test "exact mode sets data-format and a long fallback" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.relative_time id="a" at={~U[2026-11-21 09:12:00Z]} format="exact" />
        <.relative_time id="b" at={~U[2026-11-21 09:12:00Z]} />
        """)

      assert html =~ ~s(data-format="exact")
      assert html =~ "21 Nov 2026, 09:12 UTC"
      assert html =~ ~s(data-format="relative")
      assert html =~ "21 Nov 09:12 UTC"
    end
  end

  describe "occurrence stepper" do
    setup %{project: p} do
      e = insert_error(p)
      [o1, o2, o3] = for n <- 1..3, do: insert_occurrence(e, "occ-#{n}")
      %{error: e, o1: o1, o2: o2, o3: o3}
    end

    test "defaults to newest with a dimmed non-link newer arrow", c do
      {:ok, view, _} = live(c.conn, err_path(c.project, c.error))

      assert has_element?(view, "#occurrence-position", "Occurrence 1 of 3")
      assert has_element?(view, "span#occurrence-newer")
      refute has_element?(view, "a#occurrence-newer")

      assert has_element?(
               view,
               ~s(a#occurrence-older[href="#{err_path(c.project, c.error, c.o2)}"])
             )

      assert has_element?(view, "#message", "occ-3")
    end

    test "middle occurrence has both links on the existing URLs", c do
      {:ok, view, _} = live(c.conn, err_path(c.project, c.error, c.o2))

      assert has_element?(view, "#occurrence-position", "Occurrence 2 of 3")

      assert has_element?(
               view,
               ~s(a#occurrence-newer[href="#{err_path(c.project, c.error, c.o3)}"])
             )

      assert has_element?(
               view,
               ~s(a#occurrence-older[href="#{err_path(c.project, c.error, c.o1)}"])
             )

      assert has_element?(view, "#message", "occ-2")
    end

    test "oldest has a dimmed non-link older arrow", c do
      {:ok, view, _} = live(c.conn, err_path(c.project, c.error, c.o1))

      assert has_element?(view, "#occurrence-position", "Occurrence 3 of 3")
      assert has_element?(view, "span#occurrence-older")
      refute has_element?(view, "a#occurrence-older")
    end

    test "following the older link patches to that occurrence", c do
      {:ok, view, _} = live(c.conn, err_path(c.project, c.error))
      view |> element("a#occurrence-older") |> render_click()

      assert_patch(view, err_path(c.project, c.error, c.o2))
      assert has_element?(view, "#occurrence-position", "Occurrence 2 of 3")
    end

    test "unknown or foreign occurrence id falls back to newest", c do
      other = insert_error(c.project)
      foreign = insert_occurrence(other, "foreign")

      {:ok, view, _} = live(c.conn, "/project/#{c.project.key}/#{c.error.id}/999999999")
      assert has_element?(view, "#message", "occ-3")

      {:ok, view, _} = live(c.conn, "/project/#{c.project.key}/#{c.error.id}/#{foreign.id}")
      assert has_element?(view, "#message", "occ-3")
    end

    test "popover lists occurrences, marks the current one", c do
      {:ok, view, _} = live(c.conn, err_path(c.project, c.error, c.o2))

      assert has_element?(view, "#occurrences-menu[popover]")
      assert has_element?(view, ~s(button[popovertarget="occurrences-menu"]))
      assert view |> element("#occurrences-menu") |> render() |> count("data-occurrence=") == 3

      assert has_element?(
               view,
               ~s(#occurrences-menu a[data-occurrence="#{c.o2.id}"][data-current])
             )

      refute has_element?(view, "#occurrences-capped")
    end

    test "new occurrence keeps the viewed one and updates counts", c do
      {:ok, view, _} = live(c.conn, err_path(c.project, c.error, c.o2))
      insert_occurrence(c.error, "occ-4")
      send(view.pid, :refresh)

      assert has_element?(view, "#occurrence-position", "Occurrence 3 of 4")
      assert has_element?(view, "#message", "occ-2")
    end
  end

  test "popover caps at 50 and says how many exist", %{conn: conn, project: p} do
    e = insert_error(p)
    now = DateTime.utc_now()

    Repo.insert_all(
      "occurrences",
      for n <- 1..55 do
        %{
          error_id: e.id,
          reason: "r#{n}",
          context: %{},
          stacktrace: %{lines: []},
          inserted_at: now
        }
      end
    )

    {:ok, view, _} = live(conn, err_path(p, e))

    assert view |> element("#occurrences-menu") |> render() |> count("data-occurrence=") == 50
    assert has_element?(view, "#occurrences-capped", "showing 50 of 55")
    assert has_element?(view, "#occurrence-position", "Occurrence 1 of 55")
  end

  describe "stacktrace" do
    test "marks app and library frames and dims library ones", %{conn: conn, project: p} do
      e = insert_error(p)

      insert_occurrence(e, "x", [
        %Schema.Stacktrace.Line{
          application: "shop",
          module: "Elixir.Shop.Cart",
          function: "add",
          arity: 2,
          file: "lib/shop/cart.ex",
          line: 12
        },
        %Schema.Stacktrace.Line{
          application: "phoenix",
          module: "Elixir.Phoenix.Router",
          function: "call",
          arity: 2,
          file: "lib/phoenix/router.ex",
          line: 1
        },
        %Schema.Stacktrace.Line{application: nil, module: "erlang", function: "apply", arity: 2}
      ])

      {:ok, view, html} = live(conn, err_path(p, e))

      assert has_element?(view, ~s([data-frame="app"].text-zinc-900), "Shop.Cart.add/2")
      assert has_element?(view, ~s([data-frame="lib"].text-zinc-400), "Phoenix.Router.call/2")
      assert has_element?(view, ~s([data-frame="lib"]), "erlang.apply/2")
      assert has_element?(view, ~s([data-frame="lib"] span), "–")
      assert html |> count(~s(data-frame="app")) == 1
      assert html |> count(~s(data-frame="lib")) == 2

      html = view |> element("#toggle-app-frames", "Show only app frames") |> render_click()
      assert html |> count(~s(data-frame="app")) == 1
      assert html |> count(~s(data-frame="lib")) == 0

      html = view |> element("#toggle-app-frames", "Show all frames") |> render_click()
      assert html |> count(~s(data-frame="lib")) == 2
    end
  end

  describe "issue cell" do
    test "dash when nothing is possible", %{conn: conn, project: p} do
      e = insert_error(p)
      insert_occurrence(e)
      {:ok, view, _} = live(conn, err_path(p, e))
      assert has_element?(view, "#issue", "–")
      refute has_element?(view, "#issue button")
    end

    test "github issue link and create button", %{conn: conn, project: p} do
      p =
        p
        |> Ecto.Changeset.change(
          git_provider: "github",
          repository: %Schema.Project.Repository{repo: "acme/shop"}
        )
        |> Repo.update!()

      e = insert_error(p)
      insert_occurrence(e)
      {:ok, view, _} = live(conn, err_path(p, e))

      assert has_element?(
               view,
               ~s(#issue button[phx-click="create-github-issue"]),
               "Create issue"
             )

      e2 = insert_error(p, %{gh_issue: 12, git_provider: "github"})
      insert_occurrence(e2)
      {:ok, view, _} = live(conn, err_path(p, e2))

      assert has_element?(
               view,
               ~s(#issue a[href="https://github.com/acme/shop/issues/12"]),
               "GitHub #12"
             )

      refute has_element?(view, "#issue button")
    end

    test "forgejo issue link", %{conn: conn, project: p} do
      p =
        p
        |> Ecto.Changeset.change(
          git_provider: "forgejo",
          repository: %Schema.Project.Repository{repo: "acme/shop"}
        )
        |> Repo.update!()

      e = insert_error(p, %{gh_issue: 12, git_provider: "forgejo"})
      insert_occurrence(e)
      {:ok, view, _} = live(conn, err_path(p, e))
      assert has_element?(view, ~s(#issue a[href$="/acme/shop/issues/12"]), "Forgejo #12")
    end
  end

  describe "issue sync" do
    test "detail page closes and reopens a forgejo issue via Forgejo", %{conn: conn, project: p} do
      e = insert_error(p, %{gh_issue: 7, git_provider: "forgejo"})
      insert_occurrence(e)
      test = self()

      stub(Forgejo, :close_issue, fn _p, n, _u ->
        send(test, {:forgejo_close, n})
        {:ok, %{status: 200}}
      end)

      stub(Forgejo, :reopen_issue, fn _p, n, _u ->
        send(test, {:forgejo_reopen, n})
        {:ok, %{status: 200}}
      end)

      stub(Github, :close_issue, fn _, _, _ ->
        send(test, :github_close)
        {:ok, %{status: 200}}
      end)

      stub(Github, :reopen_issue, fn _, _, _ ->
        send(test, :github_reopen)
        {:ok, %{status: 200}}
      end)

      {:ok, view, _} = live(conn, err_path(p, e))
      view |> element("button", "Resolve") |> render_click()
      assert_received {:forgejo_close, 7}
      view |> element("button", "Reopen") |> render_click()
      assert_received {:forgejo_reopen, 7}
      refute_received :github_close
      refute_received :github_reopen
    end

    test "detail page reopens a github issue via Github", %{conn: conn, project: p} do
      e = insert_error(p, %{gh_issue: 8, git_provider: "github"})
      insert_occurrence(e)
      test = self()

      stub(Github, :close_issue, fn _p, n, _u ->
        send(test, {:github_close, n})
        {:ok, %{status: 200}}
      end)

      stub(Github, :reopen_issue, fn _p, n, _u ->
        send(test, {:github_reopen, n})
        {:ok, %{status: 200}}
      end)

      {:ok, view, _} = live(conn, err_path(p, e))
      view |> element("button", "Resolve") |> render_click()
      assert_received {:github_close, 8}
      view |> element("button", "Reopen") |> render_click()
      assert_received {:github_reopen, 8}
    end

    test "list page uses the error's provider", %{conn: conn, project: p} do
      e = insert_error(p, %{gh_issue: 9, git_provider: "forgejo"})
      insert_occurrence(e)
      test = self()

      stub(Forgejo, :close_issue, fn _p, n, _u ->
        send(test, {:forgejo_close, n})
        {:ok, %{status: 200}}
      end)

      stub(Forgejo, :reopen_issue, fn _p, n, _u ->
        send(test, {:forgejo_reopen, n})
        {:ok, %{status: 200}}
      end)

      stub(Github, :close_issue, fn _, _, _ ->
        send(test, :github_close)
        {:ok, %{status: 200}}
      end)

      stub(Github, :reopen_issue, fn _, _, _ ->
        send(test, :github_reopen)
        {:ok, %{status: 200}}
      end)

      {:ok, view, _} = live(conn, "/project/#{p.key}")
      view |> element("#errors-#{e.id} button", "Resolve") |> render_click()
      assert_received {:forgejo_close, 9}
      view |> element("#errors-#{e.id} button", "Reopen") |> render_click()
      assert_received {:forgejo_reopen, 9}
      refute_received :github_close
      refute_received :github_reopen
    end

    test "no issue means no call", %{conn: conn, project: p} do
      e = insert_error(p)
      insert_occurrence(e)
      stub(Forgejo, :close_issue, fn _, _, _ -> flunk("called") end)
      stub(Github, :close_issue, fn _, _, _ -> flunk("called") end)

      {:ok, view, _} = live(conn, err_path(p, e))
      view |> element("button", "Resolve") |> render_click()
      assert has_element?(view, "button", "Reopen")
    end
  end

  describe "sync failures" do
    setup %{project: p} do
      e = insert_error(p, %{gh_issue: 7, git_provider: "forgejo"})
      insert_occurrence(e)
      %{error: e}
    end

    test "detail page flashes when closing/reopening the issue fails", c do
      stub(Forgejo, :close_issue, fn _, _, _ -> {:error, :boom} end)
      stub(Forgejo, :reopen_issue, fn _, _, _ -> {:ok, %{status: 500}} end)
      {:ok, view, _} = live(c.conn, err_path(c.project, c.error))

      html = view |> element("button", "Resolve") |> render_click()
      assert html =~ "Resolved, but closing the issue failed"
      assert has_element?(view, "button", "Reopen")

      html = view |> element("button", "Reopen") |> render_click()
      assert html =~ "Reopened, but reopening the issue failed"
      assert has_element?(view, "button", "Resolve")
    end

    test "list page flashes when closing/reopening the issue fails", c do
      stub(Forgejo, :close_issue, fn _, _, _ -> {:error, :boom} end)
      stub(Forgejo, :reopen_issue, fn _, _, _ -> {:error, :boom} end)
      {:ok, view, _} = live(c.conn, "/project/#{c.project.key}")

      html = view |> element("#errors-#{c.error.id} button", "Resolve") |> render_click()
      assert html =~ "Resolved, but closing the issue failed"

      html = view |> element("#errors-#{c.error.id} button", "Reopen") |> render_click()
      assert html =~ "Reopened, but reopening the issue failed"
    end

    test "no flash when the sync succeeds", c do
      stub(Forgejo, :close_issue, fn _, _, _ -> {:ok, %{status: 200}} end)
      {:ok, view, _} = live(c.conn, err_path(c.project, c.error))
      html = view |> element("button", "Resolve") |> render_click()
      refute html =~ "issue failed"
    end

    test "sync_issue skips a missing error", c do
      assert :ok = FaultyTower.Errors.sync_issue(c.project, nil, nil, :resolved)
    end
  end

  describe "live update from a report" do
    test "posting a report for the open error updates the detail view", %{
      conn: conn,
      project: p
    } do
      stub(FaultyTower.Recorder, :notify, fn _ -> :ok end)
      post(build_conn(), ~p"/api/report/#{p.key}", data())
      error = Repo.one!(Schema.Error)

      {:ok, view, _} = live(conn, err_path(p, error))
      assert has_element?(view, "#occurrence-position", "Occurrence 1 of 1")

      post(build_conn(), ~p"/api/report/#{p.key}", data())

      assert has_element?(view, "#occurrence-position", "Occurrence 2 of 2")
    end
  end

  defp count(html, needle), do: length(String.split(html, needle)) - 1

  describe "ids scoped to the project" do
    setup %{project: project} do
      {:ok, org_b} = Organization.create("Other Org")
      {:ok, project_b} = Project.create("Other", org_b.id, "o")
      foreign = insert_error(project_b)
      insert_occurrence(foreign)
      own = insert_error(project)
      insert_occurrence(own)
      %{foreign: foreign, own: own, project_b: project_b}
    end

    test "a foreign error id under this project's URL redirects", %{
      conn: conn,
      project: project,
      foreign: foreign
    } do
      assert {:error, {:live_redirect, %{to: to, flash: flash}}} =
               live(conn, err_path(project, foreign))

      assert to == "/project/#{project.key}"
      assert flash["error"] == "Error not found"
    end

    test "resolve and unresolve ignore a foreign error id", %{
      conn: conn,
      project: project,
      foreign: foreign,
      own: own
    } do
      {:ok, lv, _html} = live(conn, err_path(project, own))

      render_click(lv, "resolve", %{"error_id" => to_string(foreign.id)})
      assert Repo.get!(Schema.Error, foreign.id).status == :unresolved

      Repo.update_all(from(e in Schema.Error, where: e.id == ^foreign.id),
        set: [status: :resolved]
      )

      render_click(lv, "unresolve", %{"error_id" => to_string(foreign.id)})
      assert Repo.get!(Schema.Error, foreign.id).status == :resolved
    end
  end

  describe "detail page acts on the error it shows" do
    test "resolve ignores a client-sent id of another error", %{conn: conn, project: p} do
      a = insert_error(p)
      b = insert_error(p)
      insert_occurrence(a)
      {:ok, view, _} = live(conn, err_path(p, a))

      render_click(view, "resolve", %{"error_id" => to_string(b.id)})

      assert Repo.get!(Schema.Error, b.id).status == :unresolved
      assert Repo.get!(Schema.Error, a.id).status == :resolved
    end

    test "a non-integer id redirects to the list", %{conn: conn, project: p} do
      assert {:error, {:live_redirect, %{to: to, flash: flash}}} =
               live(conn, "/project/#{p.key}/abc")

      assert to == "/project/#{p.key}"
      assert flash["error"] == "Error not found"
    end
  end
end
