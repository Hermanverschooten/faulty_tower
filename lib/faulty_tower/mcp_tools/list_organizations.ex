defmodule FaultyTower.MCPTools.ListOrganizations do
  use Vancouver.Tool

  alias FaultyTower.Organization

  def name, do: "list_organizations"
  def description, do: "List all organizations for the authenticated user"

  def input_schema do
    %{
      "type" => "object",
      "properties" => %{},
      "required" => []
    }
  end

  def run(conn, _params) do
    user = get_user_from_conn(conn)

    organizations = Organization.list_user_organizations(user)

    result = %{
      "organizations" =>
        Enum.map(organizations, fn org ->
          %{
            "id" => org.id,
            "name" => org.name
          }
        end)
    }

    send_json(conn, result)
  end

  defp get_user_from_conn(conn) do
    conn.assigns[:current_user]
  end
end
