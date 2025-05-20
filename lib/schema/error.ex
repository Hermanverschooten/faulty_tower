defmodule Schema.Error do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "errors" do
    field :kind, :string
    field :reason, :string
    field :source_line, :string
    field :source_function, :string
    field :status, Ecto.Enum, values: [:resolved, :unresolved], default: :unresolved
    field :fingerprint, :binary
    field :last_occurrence_at, :utc_datetime_usec
    field :count, :integer, virtual: true
    field :gh_issue, :integer

    belongs_to :project, Schema.Project
    has_many :occurrences, Schema.Occurrence, preload_order: [desc: :id]

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [
      :kind,
      :reason,
      :source_line,
      :source_function,
      :status,
      :fingerprint,
      :last_occurrence_at,
      :project_id
    ])
  end
end
