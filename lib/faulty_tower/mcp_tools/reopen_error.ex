defmodule FaultyTower.MCPTools.ReopenError do
  use Vancouver.Tool

  alias FaultyTower.Errors

  def name, do: "reopen_error"
  def description, do: "Reopen a resolved error"

  def input_schema do
    %{
      "type" => "object",
      "properties" => %{
        "error_id" => %{
          "type" => "string",
          "description" => "The error ID to reopen"
        }
      },
      "required" => ["error_id"]
    }
  end

  def run(conn, params) do
    user = get_user_from_conn(conn)
    error_id = params["error_id"]

    case Errors.get_user_error(user, String.to_integer(error_id)) do
      {:ok, error} ->
        case Errors.reopen_error(error) do
          {:ok, updated_error} ->
            # Broadcast PubSub events to update the web interface
            Phoenix.PubSub.broadcast(FaultyTower.PubSub, "error:#{updated_error.id}", :refresh)

            Phoenix.PubSub.broadcast(
              FaultyTower.PubSub,
              "project:#{error.project.key}",
              {:refresh, updated_error.id}
            )

            result = %{
              "success" => true,
              "error" => %{
                "id" => updated_error.id,
                "status" => updated_error.status
              }
            }

            send_json(conn, result)

          {:error, changeset} ->
            send_error(conn, "Failed to reopen error: #{inspect(changeset.errors)}")
        end

      {:error, :not_found} ->
        send_error(conn, "Error not found or access denied")
    end
  end

  defp get_user_from_conn(conn) do
    conn.assigns[:current_user]
  end
end
