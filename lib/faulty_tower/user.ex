defmodule FaultyTower.User do
  alias Schema.Organization
  alias FaultyTower.Repo
  import Ecto.Changeset
  import Ecto.Query

  @doc """
  List all users
  """
  def list(preload \\ []) do
    FaultyTower.Authentication.User
    |> Repo.all()
    |> Repo.preload(preload)
  end

  @doc """
  Fetch a user from the database
  """
  def fetch(id, preload \\ []) do
    case Repo.get(FaultyTower.Authentication.User, id) do
      nil -> {:error, :not_found}
      user -> {:ok, user |> Repo.preload(preload)}
    end
  end

  def update(user, attrs) do
    organization_ids = Map.get(attrs, "organizations", [])
    organizations = Repo.all(Organization |> where([o], o.id in ^organization_ids))

    user
    |> cast(attrs, [:email, :admin])
    |> put_assoc(:organizations, organizations)
    |> validate_required([:email])
    |> Repo.update()
  end

  def insert(attrs) do
    organization_ids = Map.get(attrs, "organizations", [])
    organizations = Repo.all(Organization |> where([o], o.id in ^organization_ids))
    password = Ecto.UUID.generate()

    %FaultyTower.Authentication.User{}
    |> cast(attrs, [:email, :admin])
    |> put_change(:hashed_password, Argon2.hash_pwd_salt(password))
    |> put_assoc(:organizations, organizations)
    |> validate_required([:email])
    |> Repo.insert()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :admin])
  end
end
