defmodule Schema.Stacktrace do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key false
  embedded_schema do
    embeds_many :lines, Line, primary_key: false do
      field :application, :string
      field :module, :string
      field :function, :string
      field :arity, :integer
      field :file, :string
      field :line, :integer
    end
  end

  def changeset(schema = %__MODULE__{}, attrs) do
    schema
    |> cast(attrs, [])
    |> cast_embed(:lines, with: &line_changeset/2)
  end

  def line_changeset(line = %__MODULE__.Line{}, attrs) do
    Ecto.Changeset.cast(line, attrs, ~w[application module function arity file line]a)
  end
end
