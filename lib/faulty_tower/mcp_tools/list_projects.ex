defmodule FaultyTower.MCPTools.ListProjects do
  use Vancouver.Tool

  alias FaultyTower.Project

  def name, do: "list_projects"
  def description, do: "List all projects for the authenticated user"

  def input_schema do
    %{
      "type" => "object",
      "properties" => %{
        "organization_id" => %{
          "type" => "string",
          "description" => "Optional organization ID to filter projects"
        }
      },
      "required" => []
    }
  end

  def run(conn, params) do
    user = get_user_from_conn(conn)

    projects =
      case params["organization_id"] do
        nil ->
          Project.list_user_projects(user)

        org_id ->
          Project.list_organization_projects(user, org_id)
      end

    result = %{
      "projects" =>
        Enum.map(projects, fn project ->
          %{
            "id" => project.id,
            "key" => project.key,
            "name" => project.name,
            "organization_id" => project.organization_id,
            "organization_name" => project.organization.name,
            "otp_app" => project.otp_app,
            "github_repo" => project.github && project.github.repo,
            "ntfy_topic" => project.ntfy,
            "error_count" => length(project.unresolved_errors || [])
          }
        end)
    }

    send_json(conn, result)
  end

  defp get_user_from_conn(conn) do
    conn.assigns[:current_user]
  end
end
