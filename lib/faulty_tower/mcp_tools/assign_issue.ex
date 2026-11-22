defmodule FaultyTower.MCPTools.AssignIssue do
  use Vancouver.Tool

  alias FaultyTower.{Errors, Forgejo, Repo}

  def name, do: "assign_issue"

  def description,
    do:
      "Assign an existing issue to an error (useful when multiple errors share the same root cause)"

  def input_schema do
    %{
      "type" => "object",
      "properties" => %{
        "error_id" => %{
          "type" => "string",
          "description" => "The error ID to assign the issue to"
        },
        "issue_number" => %{
          "type" => "integer",
          "description" => "The issue number to assign"
        }
      },
      "required" => ["error_id", "issue_number"]
    }
  end

  def run(conn, params) do
    user = conn.assigns[:current_user]
    error_id = params["error_id"]
    issue_number = params["issue_number"]

    with {:ok, issue_number} <- validate_issue_number(issue_number),
         {:ok, error} <- Errors.get_user_error(user, error_id) do
      error = Repo.preload(error, project: :organization)
      assign_issue_for_provider(conn, error, issue_number)
    else
      {:error, :not_found} ->
        send_error(conn, "Error not found or access denied")

      {:error, :invalid_issue_number} ->
        send_error(conn, "Invalid issue number. Must be a positive integer.")
    end
  end

  defp assign_issue_for_provider(conn, error, issue_number) do
    case error.project.git_provider do
      "github" ->
        assign_github_issue(conn, error, issue_number)

      "forgejo" ->
        assign_forgejo_issue(conn, error, issue_number)

      _ ->
        send_error(conn, "No git provider configured for this project")
    end
  end

  defp assign_github_issue(conn, error, issue_number) do
    case Errors.set_github_issue(error.id, issue_number) do
      :ok ->
        broadcast_refresh(error)

        send_json(conn, %{
          "success" => true,
          "provider" => "github",
          "issue_number" => issue_number,
          "error_id" => error.id,
          "message" => "Issue ##{issue_number} successfully assigned to error"
        })

      _ ->
        send_error(conn, "Failed to assign issue")
    end
  end

  defp assign_forgejo_issue(conn, error, issue_number) do
    if Forgejo.configured?(error.project) do
      case Errors.set_forgejo_issue(error.id, issue_number) do
        :ok ->
          broadcast_refresh(error)

          send_json(conn, %{
            "success" => true,
            "provider" => "forgejo",
            "issue_number" => issue_number,
            "error_id" => error.id,
            "message" => "Issue ##{issue_number} successfully assigned to error"
          })

        _ ->
          send_error(conn, "Failed to assign issue")
      end
    else
      send_error(conn, "Forgejo is not configured for this project's organization")
    end
  end

  defp validate_issue_number(number) when is_integer(number) and number > 0 do
    {:ok, number}
  end

  defp validate_issue_number(_), do: {:error, :invalid_issue_number}

  defp broadcast_refresh(error) do
    Phoenix.PubSub.broadcast(FaultyTower.PubSub, "error:#{error.id}", :refresh)

    Phoenix.PubSub.broadcast(
      FaultyTower.PubSub,
      "project:#{error.project.key}",
      {:refresh, error.id}
    )
  end
end
