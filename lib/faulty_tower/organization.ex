defmodule FaultyTower.Organization do
  @moduledoc """
  Organization
  """
  alias FaultyTower.Repo
  import Ecto.Changeset

  def list(preloads \\ []) do
    Repo.all(Schema.Organization)
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
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
