defmodule FaultyTower.Dashboard do
  alias FaultyTower.Repo
  import Ecto.Query

  @doc """
  The user's projects, each with `:last_error_at` (newest occurrence over all
  errors, resolved included, or nil). Sorted: projects with unresolved errors
  first, then newest error first, never-errored last, ties by name.
  """
  def projects(user) do
    user = Repo.preload(user, projects: [:organization, :unresolved_errors])

    last_error_at =
      from(e in Schema.Error,
        where: e.project_id in ^Enum.map(user.projects, & &1.id),
        group_by: e.project_id,
        select: {e.project_id, max(e.last_occurrence_at)}
      )
      |> Repo.all()
      |> Map.new()

    projects =
      user.projects
      |> Enum.map(&Map.put(&1, :last_error_at, last_error_at[&1.id]))
      |> Enum.sort_by(&sort_key/1)

    %{user | projects: projects}
  end

  defp sort_key(project) do
    {
      project.unresolved_errors == [],
      is_nil(project.last_error_at),
      if(project.last_error_at,
        do: -DateTime.to_unix(project.last_error_at, :microsecond),
        else: 0
      ),
      String.downcase(project.name)
    }
  end
end
