defmodule Schema.Project do
  @moduledoc false
  use Ecto.Schema

  @type t :: %__MODULE__{}

  schema "projects" do
    field :name, :string
    field :key, Ecto.UUID
    field :otp_app, :string
    field :ntfy, :string

    embeds_one :github, GitHub, primary_key: false, on_replace: :update do
      @type t :: %__MODULE__{}
      field :repo, :string
      field :branch, :string, default: "main"
      field :issue_repo, :string
    end

    belongs_to :organization, Schema.Organization
    has_many :users, through: [:organization, :users]

    has_many :errors, Schema.Error,
      preload_order: [desc: :last_occurrence_at],
      on_delete: :delete_all

    has_many :unresolved_errors, Schema.Error, where: [status: :unresolved]
  end
end
