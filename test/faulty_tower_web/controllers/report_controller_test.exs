defmodule FaultyTowerWeb.ReportControllerTest do
  alias FaultyTower.Organization
  alias FaultyTower.Project
  use FaultyTowerWeb.ConnCase
  use Mimic

  test "Non-existing project", %{conn: conn} do
    conn = post(conn, ~p"/api/report/dd973146-6aa5-4fa8-90a7-7703f0939bff", data())
    assert json_response(conn, 404)
  end

  test "Invalid project", %{conn: conn} do
    conn = post(conn, ~p"/api/report/no-project", data())
    assert json_response(conn, 422)
  end

  test "Valid project", %{conn: conn} do
    # Stub the notify function to prevent async task database issues
    FaultyTower.Recorder
    |> stub(:notify, fn _error -> :ok end)

    {:ok, org} = Organization.create("Test NV")
    {:ok, project} = Project.create("test", org.id, "test")
    conn = post(conn, ~p"/api/report/#{project.key}", data())
    assert json_response(conn, 200)
  end
end
