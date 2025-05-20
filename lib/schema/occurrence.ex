defmodule Schema.Occurrence do
  @moduledoc false

  import Ecto.Changeset

  use Ecto.Schema

  require Logger

  @type t :: %__MODULE__{}

  schema "occurrences" do
    field :context, :map
    field :reason, :string

    embeds_one :stacktrace, Schema.Stacktrace
    belongs_to :error, Schema.Error

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @doc false
  def changeset(occurrence, attrs) do
    occurrence
    |> cast(attrs, [:context, :reason])
    |> maybe_put_stacktrace()
    |> validate_required([:reason, :stacktrace])
    |> foreign_key_constraint(:error)
  end

  defp maybe_put_stacktrace(changeset) do
    if stacktrace = Map.get(changeset.params, "stacktrace") do
      stacktrace =
        Schema.Stacktrace.changeset(%Schema.Stacktrace{}, stacktrace)

      put_embed(changeset, :stacktrace, stacktrace)
    else
      changeset
    end
  end
end
