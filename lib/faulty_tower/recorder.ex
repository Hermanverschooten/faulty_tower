defmodule FaultyTower.Recorder do
  alias FaultyTower.Ntfy
  alias FaultyTower.Mailer
  alias FaultyTower.Email
  alias FaultyTower.Project
  alias FaultyTower.Repo
  use FaultyTowerWeb, :verified_routes

  def record(%{
        "project_id" => project_id,
        "reason" => reason,
        "stacktrace" => stacktrace,
        "error" => error,
        "context" => context
      }) do
    with {:ok, project_id} <- Ecto.UUID.cast(project_id),
         {:ok, project} <- Project.fetch_by_key(project_id) do
      error = Map.put(error, "project_id", project.id)
      upsert_error(error, stacktrace, context, reason)
    end
  end

  def upsert_error(error, stacktrace, context, reason) do
    Repo.transaction(fn ->
      error =
        Schema.Error.changeset(%Schema.Error{}, error)

      error =
        Repo.insert!(error,
          on_conflict: [set: [status: :unresolved, last_occurrence_at: DateTime.utc_now()]],
          conflict_target: [:project_id, :fingerprint]
        )

      occurrence =
        error
        |> Ecto.build_assoc(:occurrences)
        |> Schema.Occurrence.changeset(%{
          stacktrace: stacktrace,
          context: context,
          reason: reason
        })
        |> Repo.insert!()

      {error, occurrence}
    end)
  end

  def notify(error) do
    error =
      Repo.preload(error, [:occurrences, project: :users], in_parallel: false)

    occurrences =
      error.occurrences
      |> List.delete_at(0)

    if length(occurrences) == 0 do
      ntfy(error, :new)

      Email.new_error(error)
      |> Mailer.deliver()
    else
      [occ | _] = occurrences

      if DateTime.before?(occ.inserted_at, DateTime.add(DateTime.utc_now(), -6, :hour)) do
        ntfy(error, :repeat)

        Email.new_error(error)
        |> Mailer.deliver()
      end
    end
  end

  defp ntfy(%{project: %{ntfy: nil}}, _), do: :ok

  defp ntfy(error, kind) do
    Ntfy.send(%{
      topic: error.project.ntfy,
      title: "#{error.project.name}: #{if kind == :new, do: "New e", else: "E"}rror occurred",
      message: error.reason,
      actions: [
        %{
          action: "view",
          label: "Open",
          url: url(~p"/project/#{error.project.key}/#{error.id}")
        }
      ]
    })
  end
end
