defmodule Schema.Organization do
  @moduledoc false
  use Ecto.Schema

  schema "organizations" do
    field :name, :string
    has_many :projects, Schema.Project
    has_many :errors, through: [:projects, :errors]
    has_many :unresolved_errors, through: [:projects, :unresolved_errors]

    many_to_many :users, FaultyTower.Authentication.User, join_through: "users_organizations"
  end
end
