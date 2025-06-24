defmodule FaultyTower.MCPTools.ListErrors do
  use Vancouver.Tool

  alias FaultyTower.{Project, Errors}

  def name, do: "list_errors"
  def description, do: "List errors for a specific project"

  def input_schema do
    %{
      "type" => "object",
      "properties" => %{
        "project_id" => %{
          "type" => "string",
          "description" => "The project ID to list errors for"
        },
        "status" => %{
          "type" => "string",
          "enum" => ["unresolved", "resolved", "all"],
          "description" => "Filter by error status (default: unresolved)"
        },
        "limit" => %{
          "type" => "integer",
          "description" => "Maximum number of errors to return (default: 20)"
        }
      },
      "required" => ["project_id"]
    }
  end

  def run(conn, params) do
    user = get_user_from_conn(conn)
    project_id = params["project_id"]
    status = params["status"] || "unresolved"
    limit = params["limit"] || 20

    case Project.get_user_project(user, String.to_integer(project_id)) do
      {:ok, project} ->
        errors = Errors.list_project_errors(project, status, limit)

        result = %{
          "project" => %{
            "id" => project.id,
            "name" => project.name,
            "key" => project.key
          },
          "errors" =>
            Enum.map(errors, fn error ->
              %{
                "id" => error.id,
                "fingerprint" => error.fingerprint,
                "reason" => error.reason,
                "status" => error.status,
                "occurrence_count" => Map.get(error, :occurrence_count, 0),
                "first_occurrence" => error.inserted_at,
                "last_occurrence" => error.last_occurrence_at,
                "github_issue_url" => error.gh_issue,
                "context_summary" => summarize_error_context(error)
              }
            end)
        }

        send_json(conn, result)

      {:error, :not_found} ->
        send_error(conn, "Project not found or access denied")
    end
  end

  defp get_user_from_conn(conn) do
    conn.assigns[:current_user]
  end

  defp summarize_error_context(error) do
    latest_occurrence = List.first(error.occurrences || [])

    if latest_occurrence && latest_occurrence.context do
      %{
        "environment" => latest_occurrence.context["environment"],
        "request_info" => extract_request_info(latest_occurrence.context),
        "user_info" => extract_user_info(latest_occurrence.context)
      }
    else
      %{}
    end
  end

  defp extract_request_info(context) do
    case context["request"] do
      nil ->
        nil

      request ->
        %{
          "method" => request["method"],
          "path" => request["path"],
          "user_agent" => get_in(request, ["headers", "user-agent"])
        }
    end
  end

  defp extract_user_info(context) do
    case context["user"] do
      nil ->
        nil

      user ->
        %{
          "id" => user["id"],
          "email" => user["email"]
        }
    end
  end
end
