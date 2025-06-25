defmodule FaultyTower.MCPTools.CreateGithubIssue do
  use Vancouver.Tool

  alias FaultyTower.{Errors, Repo, Github}

  def name, do: "create_github_issue"
  def description, do: "Create a GitHub issue for an error"

  def input_schema do
    %{
      "type" => "object",
      "properties" => %{
        "error_id" => %{
          "type" => "string",
          "description" => "The error ID to create an issue for"
        },
        "title" => %{
          "type" => "string",
          "description" => "Issue title (defaults to error reason)"
        },
        "body" => %{
          "type" => "string",
          "description" => "Issue body (defaults to formatted error details)"
        }
      },
      "required" => ["error_id"]
    }
  end

  def run(conn, params) do
    user = get_user_from_conn(conn)
    error_id = params["error_id"]

    case Errors.get_user_error(user, error_id) do
      {:ok, error} ->
        error = Repo.preload(error, [:project, :occurrences])

        case validate_github_configured(error.project) do
          {:ok, _} ->
            title = params["title"] || error.reason
            body = params["body"] || format_github_issue_body(error)

            case Github.create_issue(error.project, title, body) do
              {:ok, issue_url} ->
                case Errors.update_github_issue(error, issue_url) do
                  {:ok, _updated_error} ->
                    result = %{
                      "success" => true,
                      "github_issue_url" => issue_url,
                      "error_id" => error.id
                    }

                    send_json(conn, result)

                  {:error, reason} ->
                    send_error(conn, "Failed to update error with issue URL: #{inspect(reason)}")
                end

              {:error, reason} ->
                send_error(conn, "Failed to create GitHub issue: #{inspect(reason)}")
            end

          {:error, :github_not_configured} ->
            send_error(conn, "GitHub is not configured for this project")
        end

      {:error, :not_found} ->
        send_error(conn, "Error not found or access denied")
    end
  end

  defp get_user_from_conn(conn) do
    conn.assigns[:current_user]
  end

  defp validate_github_configured(project) do
    if project.github && project.github.repo do
      {:ok, project}
    else
      {:error, :github_not_configured}
    end
  end

  defp format_github_issue_body(error) do
    occurrence = List.first(error.occurrences || [])

    """
    ## Error Details

    **Error:** #{error.reason}
    **First Occurrence:** #{error.inserted_at}
    **Last Occurrence:** #{error.last_occurrence_at}
    **Total Occurrences:** #{length(error.occurrences)}

    ## Stacktrace

    ```
    #{if occurrence, do: format_stacktrace_text(occurrence.stacktrace), else: "No stacktrace available"}
    ```

    ## Context

    ```json
    #{if occurrence, do: Jason.encode!(occurrence.context || %{}, pretty: true), else: "{}"}
    ```

    ---

    This issue was automatically created by FaultyTower error tracking.
    """
  end

  defp format_stacktrace_text(stacktrace_entries) do
    stacktrace_entries
    |> Enum.map(fn entry ->
      "  #{entry.module}.#{entry.function}/#{entry.arity} (#{entry.file}:#{entry.line})"
    end)
    |> Enum.join("\n")
  end
end
