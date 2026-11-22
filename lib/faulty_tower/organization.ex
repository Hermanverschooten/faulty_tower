defmodule FaultyTower.Organization do
  @moduledoc """
  Organization
  """
  alias FaultyTower.Repo
  import Ecto.Changeset

  def list(preloads \\ []) do
    import Ecto.Query

    projects_query = from(p in Schema.Project, order_by: fragment("lower(?)", p.name))

    preloads =
      Enum.map(List.wrap(preloads), fn
        :projects -> {:projects, projects_query}
        other -> other
      end)

    from(o in Schema.Organization, order_by: fragment("lower(?)", o.name))
    |> Repo.all()
    |> Repo.preload(preloads)
  end

  def fetch(id) do
    case Repo.get(Schema.Organization, id) do
      nil -> {:error, :not_found}
      org -> {:ok, org}
    end
  end

  def create(name) do
    %Schema.Organization{}
    |> changeset(%{name: name})
    |> Repo.insert()
  end

  def insert(attrs) do
    %Schema.Organization{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  def update(schema, attrs) do
    schema
    |> changeset(attrs)
    |> Repo.update()
  end

  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [:name])
    |> cast_embed(:forgejo, with: &forgejo_changeset/2)
    |> validate_required([:name])
    |> unique_constraint(:name)
  end

  def forgejo_changeset(schema, attrs) do
    schema
    |> cast(attrs, [:instance_url, :access_token, :webhook_secret])
    |> update_change(:instance_url, &trim/1)
    |> update_change(:access_token, &trim/1)
    |> update_change(:webhook_secret, &trim/1)
  end

  defp trim(nil), do: nil
  defp trim(value) when is_binary(value), do: String.trim(value)

  def list_user_organizations(user) do
    user
    |> Repo.preload(:organizations)
    |> Map.get(:organizations, [])
  end
end
