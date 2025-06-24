defmodule FaultyTower.Errors do
  @moduledoc """
  functions to list the errors and their occurrences
  """
  alias FaultyTower.Repo

  import Ecto.Query

  def fetch(id, preloads \\ []) do
    case get(id) do
      nil -> {:error, :not_found}
      error -> {:ok, Repo.preload(error, preloads)}
    end
  end

  def list(project_id) do
    from(
      e in Schema.Error,
      where: e.project_id == ^project_id,
      join: cq in subquery(count_query()),
      on: cq.error_id == e.id,
      select_merge: %{count: cq.count}
    )
    |> Repo.all()
  end

  def get(id) do
    from(
      e in Schema.Error,
      where: e.id == ^id,
      join: cq in subquery(count_query()),
      on: cq.error_id == e.id,
      select_merge: %{count: cq.count}
    )
    |> Repo.one()
  end

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

  def set_github_issue(id, gh_issue) do
    from(e in Schema.Error,
      where: e.id == ^id
    )
    |> Repo.update_all(set: [gh_issue: gh_issue, updated_at: DateTime.utc_now()])
    |> case do
      {0, _} -> :ok
      {1, _} -> :ok
      _ -> :error
    end
  end

  def find_by_repo_and_issue(repo, issue) do
    from(e in Schema.Error,
      join: p in assoc(e, :project),
      where: e.gh_issue == ^issue,
      where:
        fragment(
          "?->>'issue_repo' = ? or (?->>'repo' = ? and ?->>'issue_repo' is null)",
          p.github,
          ^repo,
          p.github,
          ^repo,
          p.github
        ),
      preload: [:project]
    )
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      error -> {:ok, error}
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

  def get_user_error(user, error_id) do
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

  defp count_query do
    from(o in Schema.Occurrence,
      group_by: o.error_id,
      select: %{error_id: o.error_id, count: count(o)}
    )
  end
end
