defmodule FaultyTower.MCPTools.SearchErrors do
  use Vancouver.Tool

  alias FaultyTower.Repo
  import Ecto.Query

  def name, do: "search_errors"
  def description, do: "Search for errors across all user projects by reason text"

  def input_schema do
    %{
      "type" => "object",
      "properties" => %{
        "search_text" => %{
          "type" => "string",
          "description" => "Text to search for in error reasons"
        },
        "status" => %{
          "type" => "string",
          "enum" => ["unresolved", "resolved", "all"],
          "description" => "Filter by error status (default: unresolved)"
        },
        "limit" => %{
          "type" => "integer",
          "description" => "Maximum number of errors to return (default: 50)"
        }
      },
      "required" => ["search_text"]
    }
  end

  def run(conn, params) do
    user = get_user_from_conn(conn)
    search_text = params["search_text"]
    status = params["status"] || "unresolved"
    limit = params["limit"] || 50

    query =
      from e in Schema.Error,
        join: p in assoc(e, :project),
        join: o in assoc(p, :organization),
        join: uo in "users_organizations",
        on: uo.organization_id == o.id,
        where: uo.user_id == ^user.id,
        where: ilike(e.reason, ^"%#{search_text}%"),
        select: %{
          error_id: e.id,
          reason: e.reason,
          status: e.status,
          fingerprint: e.fingerprint,
          last_occurrence_at: e.last_occurrence_at,
          inserted_at: e.inserted_at,
          project_id: p.id,
          project_name: p.name,
          project_key: p.key,
          organization_name: o.name
        },
        limit: ^limit,
        order_by: [desc: e.last_occurrence_at]

    query =
      case status do
        "resolved" -> where(query, [e], e.status == :resolved)
        "all" -> query
        _ -> where(query, [e], e.status == :unresolved)
      end

    # Get occurrence counts
    count_query =
      from o in Schema.Occurrence,
        group_by: o.error_id,
        select: %{error_id: o.error_id, count: count(o)}

    results =
      query
      |> join(:left, [e], cq in subquery(count_query), on: cq.error_id == e.id)
      |> select_merge([e, p, o, uo, cq], %{occurrence_count: coalesce(cq.count, 0)})
      |> Repo.all()

    result = %{
      "search_text" => search_text,
      "total_found" => length(results),
      "errors" =>
        Enum.map(results, fn error ->
          %{
            "id" => error.error_id,
            "reason" => error.reason,
            "status" => error.status,
            "fingerprint" => error.fingerprint,
            "occurrence_count" => error.occurrence_count,
            "first_occurrence" => error.inserted_at,
            "last_occurrence" => error.last_occurrence_at,
            "project" => %{
              "id" => error.project_id,
              "name" => error.project_name,
              "key" => error.project_key,
              "organization" => error.organization_name
            }
          }
        end)
    }

    send_json(conn, result)
  end

  defp get_user_from_conn(conn) do
    conn.assigns[:current_user]
  end
end
