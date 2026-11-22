defmodule FaultyTower.Errors do
  @moduledoc """
  functions to list the errors and their occurrences
  """
  alias FaultyTower.Repo

  import Ecto.Query

  def fetch(project_id, id, preloads \\ []) do
    case get(id) do
      %Schema.Error{project_id: ^project_id} = error -> {:ok, Repo.preload(error, preloads)}
      _ -> {:error, :not_found}
    end
  end

  def list(project_id, status \\ :all) do
    from(
      e in Schema.Error,
      where: e.project_id == ^project_id,
      join: cq in subquery(count_query()),
      on: cq.error_id == e.id,
      select_merge: %{count: cq.count},
      order_by: [desc: e.last_occurrence_at]
    )
    |> then(fn query ->
      if status == :all, do: query, else: where(query, [e], e.status == ^status)
    end)
    |> Repo.all()
  end

  @doc "Counts a project's errors per status, e.g. `%{unresolved: 3, resolved: 2}`."
  def status_counts(project_id) do
    counts =
      from(e in Schema.Error,
        where: e.project_id == ^project_id,
        group_by: e.status,
        select: {e.status, count(e.id)}
      )
      |> Repo.all()
      |> Map.new()

    Map.merge(%{unresolved: 0, resolved: 0}, counts)
  end

  def get(id) do
    case parse_id(id) do
      nil ->
        nil

      id ->
        from(
          e in Schema.Error,
          where: e.id == ^id,
          join: cq in subquery(count_query()),
          on: cq.error_id == e.id,
          select_merge: %{count: cq.count}
        )
        |> Repo.one()
    end
  end

  @doc """
  Fetches an occurrence of the error: the one with `occurrence_id` when it
  belongs to the error, otherwise the newest. Returns nil without occurrences.
  """
  def get_occurrence(error_id, occurrence_id) do
    with id when is_integer(id) <- parse_id(occurrence_id),
         %Schema.Occurrence{} = occurrence <-
           Repo.get_by(Schema.Occurrence, id: id, error_id: error_id) do
      occurrence
    else
      _ ->
        from(o in Schema.Occurrence,
          where: o.error_id == ^error_id,
          order_by: [desc: o.id],
          limit: 1
        )
        |> Repo.one()
    end
  end

  @doc "Position of the occurrence, 1 being the newest."
  def occurrence_position(%Schema.Occurrence{id: id, error_id: error_id}) do
    from(o in Schema.Occurrence, where: o.error_id == ^error_id and o.id >= ^id)
    |> Repo.aggregate(:count)
  end

  @doc "Ids of the next newer and next older occurrence, nil at the ends."
  def occurrence_neighbours(%Schema.Occurrence{id: id, error_id: error_id}) do
    newer =
      from(o in Schema.Occurrence,
        where: o.error_id == ^error_id and o.id > ^id,
        select: min(o.id)
      )
      |> Repo.one()

    older =
      from(o in Schema.Occurrence,
        where: o.error_id == ^error_id and o.id < ^id,
        select: max(o.id)
      )
      |> Repo.one()

    {newer, older}
  end

  @doc "The newest `limit` occurrences as `%{id, inserted_at}`, newest first."
  def recent_occurrences(error_id, limit) do
    from(o in Schema.Occurrence,
      where: o.error_id == ^error_id,
      order_by: [desc: o.id],
      limit: ^limit,
      select: %{id: o.id, inserted_at: o.inserted_at}
    )
    |> Repo.all()
  end

  defp parse_id(id) when is_integer(id), do: id

  defp parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp parse_id(_), do: nil

  @doc """
  Mirrors a status change to the linked issue: closes it when `new_status` is
  `:resolved`, reopens it otherwise. Uses the error's git provider. No-op
  without an issue or when the error is gone. Returns `:ok` or
  `{:error, reason}` from the provider call. The project needs its
  organization preloaded.
  """
  def sync_issue(_project, nil, _user, _new_status), do: :ok
  def sync_issue(_project, %{gh_issue: nil}, _user, _new_status), do: :ok

  def sync_issue(project, error, user, new_status) do
    {mod, fun} =
      case {error.git_provider, new_status} do
        {"forgejo", :resolved} -> {FaultyTower.Forgejo, :close_issue}
        {"forgejo", _} -> {FaultyTower.Forgejo, :reopen_issue}
        {_, :resolved} -> {FaultyTower.Github, :close_issue}
        {_, _} -> {FaultyTower.Github, :reopen_issue}
      end

    mod |> apply(fun, [project, error.gh_issue, user]) |> normalize_sync()
  end

  defp normalize_sync({:ok, %{status: status}}) when status in 200..299, do: :ok
  defp normalize_sync({:ok, %{status: status}}), do: {:error, {:http_status, status}}
  defp normalize_sync({:error, reason}), do: {:error, reason}
  defp normalize_sync(other), do: {:error, other}

  def resolve(id, new_status \\ :resolved) do
    from(e in Schema.Error,
      where: e.id == ^id
    )
    |> Repo.update_all(set: [status: new_status, updated_at: DateTime.utc_now()])
    |> case do
      {0, _} -> :ok
      {1, _} -> :ok
      _ -> :error
    end
  end

  @doc """
  Sets the status of an error of the project. Returns the reloaded error, or
  `{:error, :not_found}` when the id is not an error of that project.
  """
  def resolve(project_id, id, new_status) do
    with {:ok, error} <- fetch(project_id, id),
         :ok <- resolve(error.id, new_status) do
      {:ok, get(error.id)}
    end
  end

  def set_github_issue(id, gh_issue) do
    set_issue(id, gh_issue, "github")
  end

  def set_forgejo_issue(id, issue_number) do
    set_issue(id, issue_number, "forgejo")
  end

  defp set_issue(id, issue_number, provider) do
    from(e in Schema.Error,
      where: e.id == ^id
    )
    |> Repo.update_all(
      set: [gh_issue: issue_number, git_provider: provider, updated_at: DateTime.utc_now()]
    )
    |> case do
      {0, _} -> :ok
      {1, _} -> :ok
      _ -> :error
    end
  end

  def find_by_repo_and_issue(repo, issue) do
    find_by_github_repo_and_issue(repo, issue)
  end

  def find_by_github_repo_and_issue(repo, issue) do
    errors =
      from(e in Schema.Error,
        join: p in assoc(e, :project),
        where: e.gh_issue == ^issue,
        where: e.git_provider != "forgejo" or is_nil(e.git_provider),
        where:
          fragment(
            "?->>'issue_repo' = ? or (?->>'repo' = ? and ?->>'issue_repo' is null)",
            p.repository,
            ^repo,
            p.repository,
            ^repo,
            p.repository
          ),
        preload: [:project]
      )
      |> Repo.all()

    case errors do
      [] -> {:error, :not_found}
      errors -> {:ok, errors}
    end
  end

  def find_by_forgejo_repo_and_issue(repo, issue) do
    errors =
      from(e in Schema.Error,
        join: p in assoc(e, :project),
        where: e.gh_issue == ^issue,
        where: e.git_provider == "forgejo",
        where:
          fragment(
            "?->>'issue_repo' = ? or (?->>'repo' = ? and ?->>'issue_repo' is null)",
            p.repository,
            ^repo,
            p.repository,
            ^repo,
            p.repository
          ),
        preload: [project: :organization]
      )
      |> Repo.all()

    case errors do
      [] -> {:error, :not_found}
      errors -> {:ok, errors}
    end
  end

  def list_project_errors(project, status \\ "unresolved", limit \\ 20) do
    query =
      from e in Schema.Error,
        where: e.project_id == ^project.id,
        join: cq in subquery(count_query()),
        on: cq.error_id == e.id,
        select_merge: %{occurrence_count: cq.count},
        limit: ^limit,
        order_by: [desc: e.last_occurrence_at],
        preload: [:occurrences]

    query =
      case status do
        "resolved" -> where(query, [e], e.status == :resolved)
        "all" -> query
        _ -> where(query, [e], e.status == :unresolved)
      end

    Repo.all(query)
  end

  def get_user_error(user, error_id) when is_integer(error_id) do
    query =
      from e in Schema.Error,
        join: p in Schema.Project,
        on: e.project_id == p.id,
        join: o in assoc(p, :organization),
        join: uo in "users_organizations",
        on: uo.organization_id == o.id,
        where: uo.user_id == ^user.id and e.id == ^error_id,
        preload: [:project]

    case Repo.one(query) do
      nil -> {:error, :not_found}
      error -> {:ok, error}
    end
  end

  def get_user_error(user, error_id) when is_binary(error_id) do
    case Integer.parse(error_id) do
      {int_id, ""} -> get_user_error(user, int_id)
      _ -> {:error, :not_found}
    end
  end

  def resolve_error(error) do
    error
    |> Schema.Error.changeset(%{
      status: :resolved
    })
    |> Repo.update()
  end

  def reopen_error(error) do
    error
    |> Schema.Error.changeset(%{
      status: :unresolved
    })
    |> Repo.update()
  end

  def update_github_issue(error, issue_url) do
    from(e in Schema.Error,
      where: e.id == ^error.id
    )
    |> Repo.update_all(set: [gh_issue: issue_url, updated_at: DateTime.utc_now()])
    |> case do
      {1, _} -> {:ok, %{error | gh_issue: issue_url}}
      _ -> {:error, :update_failed}
    end
  end

  def create_github_issue(error) do
    alias FaultyTower.Github

    error = Repo.preload(error, [:project, :occurrences])
    occurrence = List.first(error.occurrences)

    url =
      "#{FaultyTowerWeb.Endpoint.url()}/project/#{error.project.key}/#{error.id}/#{occurrence.id}"

    with {:ok, number} <-
           Github.create_issue(
             error.project,
             error,
             occurrence,
             url
           ),
         :ok <- set_github_issue(error.id, number) do
      Phoenix.PubSub.broadcast(FaultyTower.PubSub, "error:#{error.id}", :refresh)

      Phoenix.PubSub.broadcast(
        FaultyTower.PubSub,
        "project:#{error.project.key}",
        {:refresh, error.id}
      )

      {:ok, number}
    else
      :error -> {:error, :github_issue_creation_failed}
      {:error, reason} -> {:error, reason}
    end
  end

  def create_forgejo_issue(error) do
    alias FaultyTower.Forgejo

    error = Repo.preload(error, project: :organization, occurrences: [])
    occurrence = List.first(error.occurrences)

    url =
      "#{FaultyTowerWeb.Endpoint.url()}/project/#{error.project.key}/#{error.id}/#{occurrence.id}"

    with {:ok, number} <-
           Forgejo.create_issue(
             error.project,
             error,
             occurrence,
             url
           ),
         :ok <- set_forgejo_issue(error.id, number) do
      Phoenix.PubSub.broadcast(FaultyTower.PubSub, "error:#{error.id}", :refresh)

      Phoenix.PubSub.broadcast(
        FaultyTower.PubSub,
        "project:#{error.project.key}",
        {:refresh, error.id}
      )

      {:ok, number}
    else
      :error -> {:error, :forgejo_issue_creation_failed}
      {:error, reason} -> {:error, reason}
    end
  end

  defp count_query do
    from(o in Schema.Occurrence,
      group_by: o.error_id,
      select: %{error_id: o.error_id, count: count(o)}
    )
  end
end
