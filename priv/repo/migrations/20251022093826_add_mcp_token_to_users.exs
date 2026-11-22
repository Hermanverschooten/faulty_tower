defmodule FaultyTower.Repo.Migrations.AddMcpTokenToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :mcp_token, :string
    end

    flush()

    execute(&generate_tokens_for_existing_users/0, &noop/0)

    alter table(:users) do
      modify :mcp_token, :string, null: false
    end

    create unique_index(:users, [:mcp_token])
  end

  defp generate_tokens_for_existing_users do
    import Ecto.Query

    from(u in "users", where: is_nil(u.mcp_token), select: u.id)
    |> repo().all()
    |> Enum.each(fn user_id ->
      token = Base.encode64(:crypto.strong_rand_bytes(32))

      repo().query!(
        "UPDATE users SET mcp_token = $1 WHERE id = $2",
        [token, user_id],
        log: :info
      )
    end)
  end

  defp noop, do: :ok
end
