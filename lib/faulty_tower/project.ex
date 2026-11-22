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

  @doc "Admins, and members of the project's organization, may edit it."
  def editable_by?(_project, %{admin: true}), do: true

  def editable_by?(project, user) do
    Repo.exists?(
      from(u in FaultyTower.Authentication.User,
        join: o in assoc(u, :organizations),
        where: u.id == ^user.id and o.id == ^project.organization_id
      )
    )
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
    |> cast(attrs, [:name, :key, :organization_id, :otp_app, :ntfy, :git_provider])
    |> cast_embed(:repository, with: &repository_changeset/2)
    |> validate_required([:name, :key, :organization_id, :otp_app])
    |> unique_constraint(:key)
  end

  def repository_changeset(schema, attrs) do
    schema
    |> cast(attrs, [:repo, :branch, :issue_repo])
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

  def get_user_project(user, project_key) when is_binary(project_key) do
    query =
      from p in Schema.Project,
        join: o in assoc(p, :organization),
        join: uo in "users_organizations",
        on: uo.organization_id == o.id,
        where: uo.user_id == ^user.id and p.key == ^project_key

    case Repo.one(query) do
      nil -> {:error, :not_found}
      project -> {:ok, project}
    end
  end
end
