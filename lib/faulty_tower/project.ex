defmodule FaultyTower.Project do
  @moduledoc """
  Project
  """
  alias FaultyTower.Repo
  import Ecto.Changeset
  import Ecto.Query

  def find(project_id, current_user, preloads \\ []) do
    from(
      p in Schema.Project,
      join: u in assoc(p, :users),
      where: u.id == ^current_user.id,
      where: p.key == ^project_id
    )
    |> Repo.one()
    |> case do
      nil ->
        {:error, :not_found}

      project ->
        {:ok,
         project
         |> Repo.preload(preloads)}
    end
  end

  def fetch(project_id, preloads \\ []) do
    case Repo.get(Schema.Project, project_id) do
      nil -> {:error, :not_found}
      project -> {:ok, project |> Repo.preload(preloads)}
    end
  end

  def fetch_by_key(project_id, preloads \\ []) do
    case Repo.get_by(Schema.Project, key: project_id) do
      nil -> {:error, :not_found}
      project -> {:ok, project |> Repo.preload(preloads)}
    end
  end

  def create(name, organization_id, otp_app) do
    %Schema.Project{}
    |> changeset(%{
      name: name,
      organization_id: organization_id,
      key: Ecto.UUID.generate(),
      otp_app: otp_app
    })
    |> Repo.insert()
  end

  def update(project, attrs) do
    project
    |> changeset(attrs)
    |> Repo.update()
  end

  def delete(project) do
    Repo.delete(project)
  end

  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [:name, :key, :organization_id, :otp_app, :ntfy])
    |> cast_embed(:github, with: &gh_changeset/2)
    |> validate_required([:name, :key, :organization_id, :otp_app])
    |> unique_constraint(:key)
  end

  def gh_changeset(schema, attrs) do
    schema
    |> cast(attrs, [:repo, :branch, :issue_repo])
  end

  @doc """
  Compare 2 projects so that the one with the most unresolved_errors comes first.
  """
  def compare(p1, p2) do
    lp1 = length(p1.unresolved_errors)
    lp2 = length(p2.unresolved_errors)

    cond do
      lp1 > lp2 ->
        :lt

      lp1 < lp2 ->
        :gt

      true ->
        name1 = String.downcase(p1.name)
        name2 = String.downcase(p2.name)

        cond do
          name1 > name2 -> :gt
          name1 < name2 -> :lt
          true -> :eq
        end
    end
  end

  def list_user_projects(user) do
    from(
      p in Schema.Project,
      join: o in assoc(p, :organization),
      join: uo in "users_organizations",
      on: uo.organization_id == o.id,
      where: uo.user_id == ^user.id,
      preload: [:organization, :unresolved_errors]
    )
    |> Repo.all()
  end

  def list_organization_projects(user, organization_id) do
    from(
      p in Schema.Project,
      join: o in assoc(p, :organization),
      join: uo in "users_organizations",
      on: uo.organization_id == o.id,
      where: uo.user_id == ^user.id and p.organization_id == ^organization_id,
      preload: [:organization, :unresolved_errors]
    )
    |> Repo.all()
  end

  def get_user_project(user, project_id) do
    query =
      from p in Schema.Project,
        join: o in assoc(p, :organization),
        join: uo in "users_organizations",
        on: uo.organization_id == o.id,
        where: uo.user_id == ^user.id and p.id == ^project_id

    case Repo.one(query) do
      nil -> {:error, :not_found}
      project -> {:ok, project}
    end
  end
end
