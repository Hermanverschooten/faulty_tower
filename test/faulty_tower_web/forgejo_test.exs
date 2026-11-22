defmodule FaultyTowerWeb.ForgejoTest do
  use FaultyTowerWeb.ConnCase

  alias FaultyTower.{Organization, Project, Errors, Repo}
  import ExUnit.CaptureLog
  import FaultyTower.AuthenticationFixtures

  @webhook_secret "test_secret"

  setup %{conn: conn} do
    user = user_fixture()
    {:ok, org} = Organization.create("Test Organization")

    {:ok, org} =
      org
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_embed(:forgejo, %{
        instance_url: "https://git.example.com",
        access_token: "test_token",
        webhook_secret: @webhook_secret
      })
      |> Repo.update()

    Repo.query!(
      "INSERT INTO users_organizations (user_id, organization_id) VALUES ($1, $2)",
      [user.id, org.id]
    )

    {:ok, project} = Project.create("Test Project", org.id, "test_app")

    {:ok, project} =
      project
      |> Ecto.Changeset.change(%{git_provider: "forgejo"})
      |> Ecto.Changeset.put_embed(:repository, %{
        repo: "test-org/test-repo",
        branch: "main"
      })
      |> Repo.update()

    mcp_conn =
      conn
      |> put_req_header("authorization", "Bearer #{user.mcp_token}")

    %{
      user: user,
      organization: org,
      project: project,
      conn: conn,
      mcp_conn: mcp_conn
    }
  end

  defp create_error(project, reason) do
    fingerprint = :crypto.hash(:sha256, reason) |> Base.encode16()

    error_attrs = %{
      kind: "RuntimeError",
      reason: reason,
      source_function: "test/0",
      source_line: "test.ex:1",
      fingerprint: fingerprint,
      last_occurrence_at: DateTime.utc_now(),
      project_id: project.id,
      status: :unresolved
    }

    {:ok, error} = %Schema.Error{} |> Ecto.Changeset.change(error_attrs) |> Repo.insert()
    {:ok, error}
  end

  defp sign_payload(payload) do
    :crypto.mac(:hmac, :sha256, @webhook_secret, payload) |> Base.encode16(case: :lower)
  end

  defp post_webhook(conn, payload) do
    json = Jason.encode!(payload)
    signature = sign_payload(json)

    conn
    |> put_req_header("content-type", "application/json")
    |> put_req_header("x-forgejo-signature", signature)
    |> post("/api/forgejo/webhook", json)
  end

  describe "Forgejo webhook plug" do
    test "rejects requests without signature header", %{conn: conn} do
      json =
        Jason.encode!(%{
          "action" => "closed",
          "repository" => %{"full_name" => "test-org/test-repo"},
          "issue" => %{"number" => 123}
        })

      {conn, log} =
        with_log(fn ->
          conn
          |> put_req_header("content-type", "application/json")
          |> post("/api/forgejo/webhook", json)
        end)

      assert conn.status == 400
      assert conn.resp_body == "Missing signature"
      assert log =~ "missing signature"
    end

    test "rejects requests with invalid signature", %{conn: conn} do
      json =
        Jason.encode!(%{
          "action" => "closed",
          "repository" => %{"full_name" => "test-org/test-repo"},
          "issue" => %{"number" => 123}
        })

      {conn, log} =
        with_log(fn ->
          conn
          |> put_req_header("content-type", "application/json")
          |> put_req_header("x-forgejo-signature", "invalid_signature")
          |> post("/api/forgejo/webhook", json)
        end)

      assert conn.status == 400
      assert conn.resp_body == "Signature failed"
      assert log =~ "Unable to verify"
    end

    test "rejects requests for unknown repository", %{conn: conn} do
      json =
        Jason.encode!(%{
          "action" => "closed",
          "repository" => %{"full_name" => "unknown-org/unknown-repo"},
          "issue" => %{"number" => 123}
        })

      signature = sign_payload(json)

      {conn, log} =
        with_log(fn ->
          conn
          |> put_req_header("content-type", "application/json")
          |> put_req_header("x-forgejo-signature", signature)
          |> post("/api/forgejo/webhook", json)
        end)

      assert conn.status == 404
      assert conn.resp_body == "Organization not found"
      assert log =~ "organization not found"
    end

    test "accepts requests with valid signature", %{conn: conn} do
      conn =
        post_webhook(conn, %{
          "action" => "opened",
          "repository" => %{"full_name" => "test-org/test-repo"},
          "issue" => %{"number" => 123}
        })

      assert conn.status == 200
      assert conn.resp_body == "ok"
    end
  end

  describe "Forgejo webhook controller" do
    test "closes issue resolves associated errors", %{conn: conn, project: project} do
      {:ok, error} = create_error(project, "Test error for closing")
      Errors.set_forgejo_issue(error.id, 123)

      conn =
        post_webhook(conn, %{
          "action" => "closed",
          "repository" => %{"full_name" => "test-org/test-repo"},
          "issue" => %{"number" => 123}
        })

      assert conn.status == 200

      updated_error = Repo.get!(Schema.Error, error.id)
      assert updated_error.status == :resolved
    end

    test "reopens issue unresolves associated errors", %{conn: conn, project: project} do
      {:ok, error} = create_error(project, "Test error for reopening")
      Errors.set_forgejo_issue(error.id, 456)
      Errors.resolve(error.id, :resolved)

      conn =
        post_webhook(conn, %{
          "action" => "reopened",
          "repository" => %{"full_name" => "test-org/test-repo"},
          "issue" => %{"number" => 456}
        })

      assert conn.status == 200

      updated_error = Repo.get!(Schema.Error, error.id)
      assert updated_error.status == :unresolved
    end

    test "handles multiple errors with same issue number", %{conn: conn, project: project} do
      {:ok, error1} = create_error(project, "Test error 1")
      {:ok, error2} = create_error(project, "Test error 2")
      Errors.set_forgejo_issue(error1.id, 789)
      Errors.set_forgejo_issue(error2.id, 789)

      conn =
        post_webhook(conn, %{
          "action" => "closed",
          "repository" => %{"full_name" => "test-org/test-repo"},
          "issue" => %{"number" => 789}
        })

      assert conn.status == 200

      updated_error1 = Repo.get!(Schema.Error, error1.id)
      updated_error2 = Repo.get!(Schema.Error, error2.id)
      assert updated_error1.status == :resolved
      assert updated_error2.status == :resolved
    end

    test "ignores other webhook actions", %{conn: conn} do
      conn =
        post_webhook(conn, %{
          "action" => "labeled",
          "repository" => %{"full_name" => "test-org/test-repo"},
          "issue" => %{"number" => 123}
        })

      assert conn.status == 200
      assert conn.resp_body == "ok"
    end
  end

  describe "Errors.find_by_forgejo_repo_and_issue" do
    test "finds errors by repo and issue number", %{project: project} do
      {:ok, error} = create_error(project, "Forgejo test error")
      Errors.set_forgejo_issue(error.id, 42)

      assert {:ok, [found_error]} =
               Errors.find_by_forgejo_repo_and_issue("test-org/test-repo", 42)

      assert found_error.id == error.id
    end

    test "returns error when no matching errors found" do
      assert {:error, :not_found} =
               Errors.find_by_forgejo_repo_and_issue("test-org/test-repo", 999)
    end

    test "does not find GitHub errors", %{organization: org} do
      {:ok, github_project} = Project.create("GitHub Project", org.id, "github_app")

      {:ok, github_project} =
        github_project
        |> Ecto.Changeset.change(%{git_provider: "github"})
        |> Ecto.Changeset.put_embed(:repository, %{
          repo: "test-org/test-repo",
          branch: "main"
        })
        |> Repo.update()

      {:ok, error} = create_error(github_project, "GitHub error")
      Errors.set_github_issue(error.id, 42)

      assert {:error, :not_found} =
               Errors.find_by_forgejo_repo_and_issue("test-org/test-repo", 42)
    end

    test "finds errors by issue_repo when different from repo", %{organization: org} do
      {:ok, project_with_issue_repo} = Project.create("Issue Repo Project", org.id, "issue_app")

      {:ok, project_with_issue_repo} =
        project_with_issue_repo
        |> Ecto.Changeset.change(%{git_provider: "forgejo"})
        |> Ecto.Changeset.put_embed(:repository, %{
          repo: "test-org/code-repo",
          branch: "main",
          issue_repo: "test-org/issues-repo"
        })
        |> Repo.update()

      {:ok, error} = create_error(project_with_issue_repo, "Issue repo error")
      Errors.set_forgejo_issue(error.id, 55)

      assert {:ok, [found_error]} =
               Errors.find_by_forgejo_repo_and_issue("test-org/issues-repo", 55)

      assert found_error.id == error.id
    end
  end

  describe "MCP tools - assign_issue" do
    test "assigns an issue number to an error", %{mcp_conn: mcp_conn, project: project} do
      {:ok, error} = create_error(project, "MCP test error")

      conn =
        post(mcp_conn, "/mcp", %{
          "jsonrpc" => "2.0",
          "method" => "tools/call",
          "params" => %{
            "name" => "assign_issue",
            "arguments" => %{
              "error_id" => to_string(error.id),
              "issue_number" => 123
            }
          },
          "id" => 1
        })

      response = json_response(conn, 200)
      text = get_in(response, ["result", "content", Access.at(0), "text"])
      data = Jason.decode!(text)

      assert %{
               "success" => true,
               "provider" => "forgejo",
               "issue_number" => 123,
               "error_id" => _,
               "message" => "Issue #123 successfully assigned to error"
             } = data

      updated_error = Repo.get!(Schema.Error, error.id)
      assert updated_error.gh_issue == 123
      assert updated_error.git_provider == "forgejo"
    end

    test "rejects invalid issue numbers", %{mcp_conn: mcp_conn, project: project} do
      {:ok, error} = create_error(project, "MCP test error invalid")

      conn =
        post(mcp_conn, "/mcp", %{
          "jsonrpc" => "2.0",
          "method" => "tools/call",
          "params" => %{
            "name" => "assign_issue",
            "arguments" => %{
              "error_id" => to_string(error.id),
              "issue_number" => -1
            }
          },
          "id" => 1
        })

      response = json_response(conn, 200)
      text = get_in(response, ["result", "content", Access.at(0), "text"])

      assert text =~ "Invalid" || response["result"]["isError"] == true
    end

    test "rejects when git provider is not configured", %{mcp_conn: mcp_conn, organization: org} do
      {:ok, non_forgejo_project} = Project.create("Non-Forgejo Project", org.id, "no_forgejo")

      {:ok, error} = create_error(non_forgejo_project, "Non-forgejo error")

      conn =
        post(mcp_conn, "/mcp", %{
          "jsonrpc" => "2.0",
          "method" => "tools/call",
          "params" => %{
            "name" => "assign_issue",
            "arguments" => %{
              "error_id" => to_string(error.id),
              "issue_number" => 123
            }
          },
          "id" => 1
        })

      response = json_response(conn, 200)
      text = get_in(response, ["result", "content", Access.at(0), "text"])

      assert text =~ "No git provider" || response["result"]["isError"] == true
    end
  end
end
