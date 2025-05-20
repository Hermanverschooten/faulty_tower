defmodule FaultyTower.Repo.Migrations.CreateErrorTables do
  use Ecto.Migration

  def change do
    create table(:errors,
             primary_key: [name: :id, type: :bigserial]
           ) do
      add :kind, :string, null: false
      add :reason, :text, null: false
      add :source_line, :text, null: false
      add :source_function, :text, null: false
      add :status, :string, null: false
      add :fingerprint, :string, null: false
      add :last_occurrence_at, :utc_datetime_usec, null: false
      add :project_id, references(:projects), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:errors, [:project_id, :fingerprint])
    create index(:errors, [:project_id])

    create table(:occurrences,
             primary_key: [name: :id, type: :bigserial]
           ) do
      add :context, :map, null: false
      add :reason, :text, null: false
      add :stacktrace, :map, null: false

      add :error_id,
          references(:errors,
            on_delete: :delete_all,
            column: :id,
            type: :bigserial
          ),
          null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:occurrences, [:error_id])
  end
end
