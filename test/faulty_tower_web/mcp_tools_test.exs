defmodule FaultyTowerWeb.MCPToolsTest do
  use FaultyTowerWeb.ConnCase

  alias FaultyTower.{Organization, Project, Authentication, Errors}
  import FaultyTower.AuthenticationFixtures

  setup %{conn: conn} do
    # Create a test user using proper fixtures
    user = user_fixture()

    # Create test organization
    {:ok, org} = Organization.create("Test Organization")

    # Add user to organization using raw SQL
    FaultyTower.Repo.query!(
      "INSERT INTO users_organizations (user_id, organization_id) VALUES ($1, $2)",
      [user.id, org.id]
    )

    # Create test project
    {:ok, project} = Project.create("Test Project", org.id, "test_app")

    # Create a valid session token for the user
    token = Authentication.generate_user_session_token(user)
    encoded_token = Base.encode64(token)

    # Create MCP authenticated connection
    mcp_conn =
      conn
      |> put_req_header("authorization", "Bearer #{encoded_token}")

    %{
      user: user,
      organization: org,
      project: project,
      mcp_conn: mcp_conn
    }
  end

  describe "MCP Tools Authentication" do
    test "requires authentication", %{conn: conn} do
      conn =
        post(conn, "/mcp", %{
          "jsonrpc" => "2.0",
          "method" => "tools/call",
          "params" => %{
            "name" => "list_organizations",
            "arguments" => %{}
          },
          "id" => 1
        })

      assert conn.status == 401
    end
  end

  describe "list_organizations" do
    test "returns user organizations", %{mcp_conn: mcp_conn, organization: _org} do
      conn =
        post(mcp_conn, "/mcp", %{
          "jsonrpc" => "2.0",
          "method" => "tools/call",
          "params" => %{
            "name" => "list_organizations",
            "arguments" => %{}
          },
          "id" => 1
        })

      assert json_response(conn, 200)
      response = json_response(conn, 200)

      assert %{
               "jsonrpc" => "2.0",
               "result" => %{
                 "content" => [
                   %{
                     "text" => text,
                     "type" => "text"
                   }
                 ],
                 "isError" => false
               },
               "id" => 1
             } = response

      data = Jason.decode!(text)
      assert %{"organizations" => organizations} = data
      assert length(organizations) == 1

      [organization] = organizations

      assert %{
               "id" => _,
               "name" => "Test Organization"
             } = organization
    end

    test "returns empty list when user has no organizations", %{conn: conn} do
      # Create user with no organizations
      user = user_fixture()

      # Create valid session token for this user
      token = Authentication.generate_user_session_token(user)
      encoded_token = Base.encode64(token)

      mcp_conn =
        conn
        |> put_req_header("authorization", "Bearer #{encoded_token}")

      conn =
        post(mcp_conn, "/mcp", %{
          "jsonrpc" => "2.0",
          "method" => "tools/call",
          "params" => %{
            "name" => "list_organizations",
            "arguments" => %{}
          },
          "id" => 1
        })

      response = json_response(conn, 200)
      text = get_in(response, ["result", "content", Access.at(0), "text"])
      data = Jason.decode!(text)

      assert %{"organizations" => []} = data
    end
  end

  describe "list_projects" do
    test "returns user projects", %{mcp_conn: mcp_conn, project: _project, organization: _org} do
      conn =
        post(mcp_conn, "/mcp", %{
          "jsonrpc" => "2.0",
          "method" => "tools/call",
          "params" => %{
            "name" => "list_projects",
            "arguments" => %{}
          },
          "id" => 1
        })

      response = json_response(conn, 200)
      text = get_in(response, ["result", "content", Access.at(0), "text"])
      data = Jason.decode!(text)

      assert %{"projects" => projects} = data
      assert length(projects) == 1

      [returned_project] = projects

      assert %{
               "id" => _,
               "name" => "Test Project",
               "organization_name" => "Test Organization",
               "otp_app" => "test_app",
               "error_count" => 0
             } = returned_project
    end

    test "filters projects by organization", %{mcp_conn: mcp_conn, organization: org, user: user} do
      # Create another organization and project
      {:ok, org2} = Organization.create("Other Organization")
      {:ok, _project2} = Project.create("Other Project", org2.id, "other_app")

      # Add user to second organization
      FaultyTower.Repo.query!(
        "INSERT INTO users_organizations (user_id, organization_id) VALUES ($1, $2)",
        [user.id, org2.id]
      )

      # Filter by first organization
      conn =
        post(mcp_conn, "/mcp", %{
          "jsonrpc" => "2.0",
          "method" => "tools/call",
          "params" => %{
            "name" => "list_projects",
            "arguments" => %{
              "organization_id" => to_string(org.id)
            }
          },
          "id" => 1
        })

      response = json_response(conn, 200)
      text = get_in(response, ["result", "content", Access.at(0), "text"])
      data = Jason.decode!(text)

      assert %{"projects" => projects} = data
      assert length(projects) == 1

      [project] = projects
      assert project["organization_name"] == "Test Organization"
    end
  end

  describe "search_errors" do
    setup %{project: project} do
      # Create some test errors
      {:ok, error1} = create_error(project, "Connection timeout")
      {:ok, error2} = create_error(project, "Database connection failed")
      {:ok, error3} = create_error(project, "File not found")

      %{errors: [error1, error2, error3]}
    end

    test "searches errors by text", %{mcp_conn: mcp_conn} do
      conn =
        post(mcp_conn, "/mcp", %{
          "jsonrpc" => "2.0",
          "method" => "tools/call",
          "params" => %{
            "name" => "search_errors",
            "arguments" => %{
              "search_text" => "connection"
            }
          },
          "id" => 1
        })

      response = json_response(conn, 200)
      text = get_in(response, ["result", "content", Access.at(0), "text"])
      data = Jason.decode!(text)

      assert %{
               "search_text" => "connection",
               "total_found" => 2,
               "errors" => errors
             } = data

      assert length(errors) == 2
      reasons = Enum.map(errors, & &1["reason"])
      assert "Connection timeout" in reasons
      assert "Database connection failed" in reasons
    end

    test "filters by status", %{mcp_conn: mcp_conn, errors: [error1, _error2, _error3]} do
      # Resolve one error
      {:ok, _} = Errors.resolve_error(error1)

      # Search for resolved errors
      conn =
        post(mcp_conn, "/mcp", %{
          "jsonrpc" => "2.0",
          "method" => "tools/call",
          "params" => %{
            "name" => "search_errors",
            "arguments" => %{
              "search_text" => "connection",
              "status" => "resolved"
            }
          },
          "id" => 1
        })

      response = json_response(conn, 200)
      text = get_in(response, ["result", "content", Access.at(0), "text"])
      data = Jason.decode!(text)

      assert %{
               "total_found" => 1,
               "errors" => [error]
             } = data

      assert error["status"] == "resolved"
      assert error["reason"] == "Connection timeout"
    end

    test "respects limit parameter", %{mcp_conn: mcp_conn} do
      conn =
        post(mcp_conn, "/mcp", %{
          "jsonrpc" => "2.0",
          "method" => "tools/call",
          "params" => %{
            "name" => "search_errors",
            "arguments" => %{
              "search_text" => "",
              "limit" => 1
            }
          },
          "id" => 1
        })

      response = json_response(conn, 200)
      text = get_in(response, ["result", "content", Access.at(0), "text"])
      data = Jason.decode!(text)

      assert %{"errors" => errors} = data
      assert length(errors) <= 1
    end
  end

  describe "list_errors" do
    setup %{project: project} do
      {:ok, error1} = create_error(project, "Test error 1")
      {:ok, error2} = create_error(project, "Test error 2")
      {:ok, _} = Errors.resolve_error(error2)

      %{unresolved_error: error1, resolved_error: error2}
    end

    test "lists errors for a project", %{mcp_conn: mcp_conn, project: project} do
      conn =
        post(mcp_conn, "/mcp", %{
          "jsonrpc" => "2.0",
          "method" => "tools/call",
          "params" => %{
            "name" => "list_errors",
            "arguments" => %{
              "project_id" => to_string(project.id)
            }
          },
          "id" => 1
        })

      response = json_response(conn, 200)
      text = get_in(response, ["result", "content", Access.at(0), "text"])
      data = Jason.decode!(text)

      assert %{
               "project" => %{
                 "name" => "Test Project"
               },
               "errors" => errors
             } = data

      # Should only return unresolved by default
      assert length(errors) == 1
      [error] = errors
      assert error["status"] == "unresolved"
    end

    test "filters by status", %{mcp_conn: mcp_conn, project: project} do
      conn =
        post(mcp_conn, "/mcp", %{
          "jsonrpc" => "2.0",
          "method" => "tools/call",
          "params" => %{
            "name" => "list_errors",
            "arguments" => %{
              "project_id" => to_string(project.id),
              "status" => "all"
            }
          },
          "id" => 1
        })

      response = json_response(conn, 200)
      text = get_in(response, ["result", "content", Access.at(0), "text"])
      data = Jason.decode!(text)

      assert %{"errors" => errors} = data
      assert length(errors) == 2
    end

    test "denies access to other user's projects", %{conn: conn, project: project} do
      # Create different user
      other_user = user_fixture()

      # Create valid session token for the other user
      other_token = Authentication.generate_user_session_token(other_user)
      other_encoded_token = Base.encode64(other_token)

      other_mcp_conn =
        conn
        |> put_req_header("authorization", "Bearer #{other_encoded_token}")

      conn =
        post(other_mcp_conn, "/mcp", %{
          "jsonrpc" => "2.0",
          "method" => "tools/call",
          "params" => %{
            "name" => "list_errors",
            "arguments" => %{
              "project_id" => to_string(project.id)
            }
          },
          "id" => 1
        })

      response = json_response(conn, 200)
      assert get_in(response, ["result", "isError"]) == true
      error_text = get_in(response, ["result", "content", Access.at(0), "text"])
      assert error_text =~ "not found or access denied"
    end
  end

  describe "resolve_error" do
    setup %{project: project} do
      {:ok, error} = create_error(project, "Test error")
      %{error: error}
    end

    test "resolves an error", %{mcp_conn: mcp_conn, error: error} do
      conn =
        post(mcp_conn, "/mcp", %{
          "jsonrpc" => "2.0",
          "method" => "tools/call",
          "params" => %{
            "name" => "resolve_error",
            "arguments" => %{
              "error_id" => to_string(error.id)
            }
          },
          "id" => 1
        })

      response = json_response(conn, 200)
      text = get_in(response, ["result", "content", Access.at(0), "text"])
      data = Jason.decode!(text)

      assert %{
               "success" => true,
               "error" => %{
                 "id" => _,
                 "status" => "resolved"
               }
             } = data

      # Verify error is actually resolved in database
      updated_error = FaultyTower.Repo.get!(Schema.Error, error.id)
      assert updated_error.status == :resolved
    end

    test "denies access to other user's errors", %{conn: conn, error: error} do
      # Create different user
      other_user = user_fixture()

      # Create valid session token for the other user
      other_token = Authentication.generate_user_session_token(other_user)
      other_encoded_token = Base.encode64(other_token)

      other_mcp_conn =
        conn
        |> put_req_header("authorization", "Bearer #{other_encoded_token}")

      conn =
        post(other_mcp_conn, "/mcp", %{
          "jsonrpc" => "2.0",
          "method" => "tools/call",
          "params" => %{
            "name" => "resolve_error",
            "arguments" => %{
              "error_id" => to_string(error.id)
            }
          },
          "id" => 1
        })

      response = json_response(conn, 200)
      assert get_in(response, ["result", "isError"]) == true
      error_text = get_in(response, ["result", "content", Access.at(0), "text"])
      assert error_text =~ "not found or access denied"
    end
  end

  describe "reopen_error" do
    setup %{project: project} do
      {:ok, error} = create_error(project, "Test error")
      {:ok, resolved_error} = Errors.resolve_error(error)
      %{error: resolved_error}
    end

    test "reopens a resolved error", %{mcp_conn: mcp_conn, error: error} do
      conn =
        post(mcp_conn, "/mcp", %{
          "jsonrpc" => "2.0",
          "method" => "tools/call",
          "params" => %{
            "name" => "reopen_error",
            "arguments" => %{
              "error_id" => to_string(error.id)
            }
          },
          "id" => 1
        })

      response = json_response(conn, 200)
      text = get_in(response, ["result", "content", Access.at(0), "text"])
      data = Jason.decode!(text)

      assert %{
               "success" => true,
               "error" => %{
                 "id" => _,
                 "status" => "unresolved"
               }
             } = data

      # Verify error is actually reopened in database
      updated_error = FaultyTower.Repo.get!(Schema.Error, error.id)
      assert updated_error.status == :unresolved
    end
  end

  # Helper function to create test errors directly in the database
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

    error =
      %Schema.Error{}
      |> Schema.Error.changeset(error_attrs)
      |> FaultyTower.Repo.insert!()

    # Create an occurrence for the error
    occurrence_attrs = %{
      "reason" => reason,
      "stacktrace" => %{
        "lines" => [
          %{
            "application" => "test_app",
            "file" => "test.ex",
            "line" => 1,
            "module" => "TestModule",
            "function" => "test",
            "arity" => 0
          }
        ]
      },
      "context" => %{
        "environment" => "test"
      }
    }

    _occurrence =
      %Schema.Occurrence{error_id: error.id}
      |> Schema.Occurrence.changeset(occurrence_attrs)
      |> FaultyTower.Repo.insert!()

    {:ok, error}
  end
end
