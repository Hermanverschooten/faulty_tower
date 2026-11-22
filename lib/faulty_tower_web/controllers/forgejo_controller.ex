defmodule FaultyTowerWeb.ForgejoController do
  alias FaultyTower.Errors
  use FaultyTowerWeb, :controller

  require Logger

  def webhook(conn, %{
        "action" => action,
        "repository" => %{"full_name" => repo},
        "issue" => %{"number" => number}
      })
      when action in ["closed", "reopened"] do
    with {:ok, errors} <- Errors.find_by_forgejo_repo_and_issue(repo, number) do
      new_status =
        case action do
          "closed" -> :resolved
          "reopened" -> :unresolved
        end

      Enum.each(errors, fn error ->
        Errors.resolve(error.id, new_status)
        Phoenix.PubSub.broadcast(FaultyTower.PubSub, "error:#{error.id}", :refresh)

        Phoenix.PubSub.broadcast(
          FaultyTower.PubSub,
          "project:#{error.project.key}",
          {:refresh, error.id}
        )
      end)
    end

    conn
    |> text("ok")
  end

  def webhook(conn, params) do
    Logger.debug("Forgejo webhook received: #{inspect(params)}")

    conn
    |> text("ok")
  end
end
