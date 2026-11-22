defmodule FaultyTower.MCPTools.CreateIssue do
  use Vancouver.Tool

  alias FaultyTower.{Errors, Forgejo, Repo}

  def name, do: "create_issue"
  def description, do: "Create an issue for an error in the project's configured git provider"

  def input_schema do
    %{
      "type" => "object",
      "properties" => %{
        "error_id" => %{
          "type" => "string",
          "description" => "The error ID to create an issue for"
        }
      },
      "required" => ["error_id"]
    }
  end

  def run(conn, params) do
    user = conn.assigns[:current_user]
    error_id = params["error_id"]

    case Errors.get_user_error(user, error_id) do
      {:ok, error} ->
        error = Repo.preload(error, project: :organization)
        create_issue_for_provider(conn, error)

      {:error, :not_found} ->
        send_error(conn, "Error not found or access denied")
    end
  end

  defp create_issue_for_provider(conn, error) do
    case error.project.git_provider do
      "github" ->
        create_github_issue(conn, error)

      "forgejo" ->
        create_forgejo_issue(conn, error)

      _ ->
        send_error(conn, "No git provider configured for this project")
    end
  end

  defp create_github_issue(conn, error) do
    case Errors.create_github_issue(error) do
      {:ok, number} ->
        send_json(conn, %{
          "success" => true,
          "provider" => "github",
          "issue_number" => number,
          "error_id" => error.id
        })

      {:error, reason} ->
        send_error(conn, "Failed to create GitHub issue: #{inspect(reason)}")
    end
  end

  defp create_forgejo_issue(conn, error) do
    if Forgejo.configured?(error.project) do
      case Errors.create_forgejo_issue(error) do
        {:ok, number} ->
          send_json(conn, %{
            "success" => true,
            "provider" => "forgejo",
            "issue_number" => number,
            "error_id" => error.id
          })

        {:error, reason} ->
          send_error(conn, "Failed to create Forgejo issue: #{inspect(reason)}")
      end
    else
      send_error(conn, "Forgejo is not configured for this project's organization")
    end
  end
end
