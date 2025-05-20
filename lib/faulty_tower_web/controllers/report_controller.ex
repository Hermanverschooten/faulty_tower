defmodule FaultyTowerWeb.ReportController do
  alias FaultyTower.Recorder
  use FaultyTowerWeb, :controller

  def receive(conn, params) do
    case Recorder.record(params) do
      {:ok, {error, _}} ->
        Phoenix.PubSub.broadcast(
          FaultyTower.PubSub,
          "project:#{params["project_id"]}",
          {:add, error.id}
        )

        Task.start(fn -> Recorder.notify(error) end)

        conn
        |> json(:ok)

      {:error, :not_found} ->
        conn
        |> put_status(404)
        |> json(%{project_id: params["project_id"]})

      :error ->
        conn
        |> put_status(422)
        |> json(:error)
    end
  end
end
