defmodule Schema.Organization do
  @moduledoc false
  use Ecto.Schema

  @type t :: %__MODULE__{}

  schema "organizations" do
    field :name, :string

    embeds_one :forgejo, Forgejo, primary_key: false, on_replace: :update do
      @type t :: %__MODULE__{}
      field :instance_url, :string
      field :access_token, :string
      field :webhook_secret, :string
    end

    has_many :projects, Schema.Project
    has_many :errors, through: [:projects, :errors]
    has_many :unresolved_errors, through: [:projects, :unresolved_errors]

    many_to_many :users, FaultyTower.Authentication.User, join_through: "users_organizations"
  end
end
