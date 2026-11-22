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
          "description" => "The project UUID key"
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
    project_key = params["project_id"]
    status = params["status"] || "unresolved"
    limit = params["limit"] || 20

    with :ok <- validate_uuid(project_key),
         {:ok, project} <- Project.get_user_project(user, project_key) do
      errors = Errors.list_project_errors(project, status, limit)

      result = %{
        "project" => %{
          "project_id" => project.key,
          "name" => project.name
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
    else
      {:error, :invalid_uuid} ->
        send_error(conn, "Invalid project UUID format")

      {:error, :not_found} ->
        send_error(conn, "Project not found or access denied")
    end
  end

  defp get_user_from_conn(conn) do
    conn.assigns[:current_user]
  end

  defp validate_uuid(uuid) when is_binary(uuid) do
    case Ecto.UUID.cast(uuid) do
      {:ok, _} -> :ok
      :error -> {:error, :invalid_uuid}
    end
  end

  defp validate_uuid(_), do: {:error, :invalid_uuid}

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
      user when is_map(user) ->
        %{
          "id" => user["id"],
          "email" => user["email"]
        }

      user when is_binary(user) ->
        user

      _ ->
        nil
    end
  end
end
