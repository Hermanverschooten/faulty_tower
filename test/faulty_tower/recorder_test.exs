defmodule FaultyTower.RecorderTest do
  alias FaultyTower.Organization
  alias FaultyTower.Project
  use FaultyTower.DataCase

  alias FaultyTower.Recorder

  test "record new error" do
    assert {:ok, org} = Organization.create("test")
    assert {:ok, project} = Project.create("test", org.id, "test")

    data = data() |> Map.put("project_id", project.key)

    assert {:ok, {error, _occurrence}} = Recorder.record(data)

    assert error.status == :unresolved
  end

  test "Notify on existing error if previous occurrence is older than 6 hours" do
    assert {:ok, org} = Organization.create("test")
    assert {:ok, project} = Project.create("test", org.id, "test")

    data = data() |> Map.put("project_id", project.key)

    assert {:ok, {error, occurrence}} = Recorder.record(data)

    occurrence = %{
      occurrence
      | inserted_at: DateTime.add(DateTime.utc_now(), -7, :hour),
        id: occurrence.id - 2
    }

    FaultyTower.Repo.insert(occurrence)

    assert {:ok, _} = Recorder.notify(error)
  end

  test "record error report containing null bytes" do
    assert {:ok, org} = Organization.create("test")
    assert {:ok, project} = Project.create("test", org.id, "test")

    data =
      data()
      |> Map.put("project_id", project.key)
      |> Map.put("reason", "no function clause matching\u0000 in Date.convert/2")
      |> update_in(["context", "username"], &(&1 <> "\u0000"))
      |> update_in(["error", "reason"], &(&1 <> "\u0000"))

    assert {:ok, {error, occurrence}} = Recorder.record(data)

    refute String.contains?(error.reason, "\u0000")
    refute String.contains?(occurrence.reason, "\u0000")
    refute String.contains?(occurrence.context["username"], "\u0000")
  end

  test "Do not notify on existing error if previous occurrence is younger than 6 hours" do
    assert {:ok, org} = Organization.create("test")
    assert {:ok, project} = Project.create("test", org.id, "test")

    data = data() |> Map.put("project_id", project.key)

    assert {:ok, {error, occurrence}} = Recorder.record(data)

    occurrence = %{
      occurrence
      | inserted_at: DateTime.add(DateTime.utc_now(), -2, :hour),
        id: occurrence.id - 2
    }

    FaultyTower.Repo.insert(occurrence)

    refute Recorder.notify(error)
  end
end
