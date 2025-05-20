defmodule FaultyTowerWeb.GitHub do
  @behaviour Plug

  import Plug.Conn

  require Logger

  def init(config), do: config

  def call(%{request_path: "/api/gh/webhook"} = conn, _) do
    secret = System.get_env("GH_CLIENT_SECRET")
    ["sha256=" <> signature] = get_req_header(conn, "X-Hub-Signature-256")

    with {:ok, body, conn} <- read_whole_body(conn) do
      calculated_signature =
        :crypto.mac(:hmac, :sha256, secret, body) |> Base.encode16(case: :lower)

      if calculated_signature == signature do
        Logger.info("GitHub Webhook signature verified")
        conn
      else
        Logger.error("Unable to verify GitHub Webhook signature")

        conn
        |> send_resp(:bad_request, "Signature failed")
        |> halt()
      end
    end
  end

  def call(conn, _), do: conn

  defp read_whole_body(conn, read \\ "")

  defp read_whole_body(conn, read) do
    case read_body(conn) do
      {:ok, body, conn} ->
        {:ok, read <> body, conn}

      {:more, body, conn} ->
        read_whole_body(conn, read <> body)

      {:error, error} ->
        {:error, error}
    end
  end
end
