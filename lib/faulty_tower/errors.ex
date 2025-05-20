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

  defp count_query do
    from(o in Schema.Occurrence,
      group_by: o.error_id,
      select: %{error_id: o.error_id, count: count(o)}
    )
  end
end
