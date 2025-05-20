defmodule FaultyTowerWeb.GitHubController do
  alias FaultyTower.Errors
  use FaultyTowerWeb, :controller

  def webhook(conn, %{
        "action" => action,
        "repository" => %{"full_name" => repo},
        "issue" => %{"number" => number}
      })
      when action in ["closed", "reopened"] do
    with {:ok, error} <- Errors.find_by_repo_and_issue(repo, number) do
      new_status =
        case action do
          "closed" ->
            :resolved

          "reopened" ->
            :unresolved
        end

      Errors.resolve(error.id, new_status)
      Phoenix.PubSub.broadcast(FaultyTower.PubSub, "error:#{error.id}", :refresh)

      Phoenix.PubSub.broadcast(
        FaultyTower.PubSub,
        "project:#{error.project.key}",
        {:refresh, error.id}
      )
    end

    conn
    |> text("ok")
  end

  def webhook(conn, params) do
    IO.inspect(params)

    conn
    |> text("ok")
  end
end
