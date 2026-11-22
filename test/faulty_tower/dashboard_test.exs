defmodule FaultyTower.DashboardTest do
  use FaultyTower.DataCase

  import FaultyTower.AuthenticationFixtures

  alias FaultyTower.{Dashboard, Organization, Project}

  defp insert_error(project, status, last_occurrence_at) do
    Repo.insert!(%Schema.Error{
      project_id: project.id,
      status: status,
      kind: "RuntimeError",
      reason: "boom",
      source_line: "x.ex:1",
      source_function: "f/1",
      fingerprint: Base.encode16(:crypto.strong_rand_bytes(8)),
      last_occurrence_at: last_occurrence_at
    })
  end

  test "projects/1 sorts unresolved first, then newest error, never-errored last" do
    user = user_fixture()
    {:ok, org} = Organization.create("org")
    Repo.insert_all("users_organizations", [%{user_id: user.id, organization_id: org.id}])

    now = DateTime.utc_now()
    ago = fn h -> DateTime.add(now, -h, :hour) end

    {:ok, never} = Project.create("a-never", org.id, "a")
    {:ok, old_unresolved} = Project.create("b-old-unresolved", org.id, "b")
    {:ok, new_unresolved} = Project.create("c-new-unresolved", org.id, "c")
    {:ok, resolved_new} = Project.create("d-resolved-new", org.id, "d")
    {:ok, resolved_old} = Project.create("e-resolved-old", org.id, "e")

    insert_error(old_unresolved, :unresolved, ago.(10))
    insert_error(new_unresolved, :unresolved, ago.(2))
    insert_error(new_unresolved, :resolved, ago.(1))
    insert_error(resolved_new, :resolved, ago.(3))
    insert_error(resolved_old, :resolved, ago.(20))

    %{projects: projects} = Dashboard.projects(user)

    assert Enum.map(projects, & &1.name) == [
             "c-new-unresolved",
             "b-old-unresolved",
             "d-resolved-new",
             "e-resolved-old",
             "a-never"
           ]

    by_id = Map.new(projects, &{&1.id, &1})
    # last_error_at covers resolved errors too
    assert DateTime.compare(by_id[new_unresolved.id].last_error_at, ago.(1)) == :eq
    assert by_id[never.id].last_error_at == nil
  end
end
