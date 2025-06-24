defmodule FaultyTower.MCPTools.GetErrorDetails do
  use Vancouver.Tool

  alias FaultyTower.{Errors, Repo}

  def name, do: "get_error_details"

  def description,
    do: "Get detailed information about a specific error including stacktrace for AI analysis"

  def input_schema do
    %{
      "type" => "object",
      "properties" => %{
        "error_id" => %{
          "type" => "string",
          "description" => "The error ID to get details for"
        },
        "include_occurrences" => %{
          "type" => "boolean",
          "description" => "Include all occurrences (default: false, only latest)"
        }
      },
      "required" => ["error_id"]
    }
  end

  def run(conn, params) do
    user = get_user_from_conn(conn)
    error_id = params["error_id"]
    include_all = params["include_occurrences"] || false

    case Errors.get_user_error(user, error_id) do
      {:ok, error} ->
        error = Repo.preload(error, [:occurrences, :project])

        occurrences =
          if include_all do
            error.occurrences
          else
            case List.first(error.occurrences) do
              nil -> []
              occ -> [occ]
            end
          end

        result = %{
          "error" => %{
            "id" => error.id,
            "fingerprint" => error.fingerprint,
            "reason" => error.reason,
            "status" => error.status,
            "occurrence_count" => Map.get(error, :occurrence_count, length(error.occurrences)),
            "first_occurrence" => error.inserted_at,
            "last_occurrence" => error.last_occurrence_at,
            "github_issue_url" => error.gh_issue,
            "project" => %{
              "id" => error.project.id,
              "name" => error.project.name,
              "key" => error.project.key,
              "otp_app" => error.project.otp_app
            }
          },
          "occurrences" =>
            Enum.map(occurrences, fn occ ->
              %{
                "id" => occ.id,
                "timestamp" => occ.inserted_at,
                "stacktrace" => format_stacktrace_for_ai(occ.stacktrace),
                "context" => occ.context,
                "reason" => occ.reason
              }
            end),
          "ai_analysis_prompt" => generate_ai_prompt(error, List.first(occurrences))
        }

        send_json(conn, result)

      {:error, :not_found} ->
        send_error(conn, "Error not found or access denied")
    end
  end

  defp get_user_from_conn(conn) do
    conn.assigns[:current_user]
  end

  defp format_stacktrace_for_ai(%Schema.Stacktrace{lines: lines}) do
    Enum.map(lines || [], fn entry ->
      %{
        "file" => entry.file,
        "function" => entry.function,
        "line" => entry.line,
        "module" => entry.module,
        "arity" => entry.arity,
        "application" => entry.application
      }
    end)
  end

  defp format_stacktrace_for_ai(nil), do: []

  defp generate_ai_prompt(error, occurrence) when not is_nil(occurrence) do
    """
    Error Analysis Request:

    Application: #{error.project.name} (#{error.project.otp_app})
    Error Type: #{error.reason}
    Occurrence Count: #{Map.get(error, :occurrence_count, length(error.occurrences))}

    Most Recent Stacktrace:
    #{format_stacktrace_text(occurrence.stacktrace)}

    Context:
    #{Jason.encode!(occurrence.context || %{}, pretty: true)}

    Please analyze this error and suggest:
    1. The root cause of the error
    2. Potential fixes or workarounds
    3. Steps to prevent similar errors in the future
    """
  end

  defp generate_ai_prompt(_error, nil), do: "No occurrence data available for analysis."

  defp format_stacktrace_text(%Schema.Stacktrace{lines: lines}) do
    lines
    |> Enum.map(fn entry ->
      "  #{entry.module}.#{entry.function}/#{entry.arity} (#{entry.file}:#{entry.line})"
    end)
    |> Enum.join("\n")
  end

  defp format_stacktrace_text(nil), do: "No stacktrace available"
end
