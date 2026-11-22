defmodule FaultyTowerWeb.Plugs.GitHub do
  @moduledoc """
  Plug for verifying GitHub webhook signatures.

  This plug verifies that incoming webhook requests from GitHub have a valid
  HMAC-SHA256 signature using the GH_CLIENT_SECRET environment variable.
  """
  @behaviour Plug

  import Plug.Conn

  require Logger

  def init(config), do: config

  def call(%{request_path: "/api/gh/webhook"} = conn, _) do
    secret = System.get_env("GH_CLIENT_SECRET")
    body = conn.assigns[:raw_body] || ""

    case get_req_header(conn, "x-hub-signature-256") do
      ["sha256=" <> signature] ->
        calculated_signature =
          :crypto.mac(:hmac, :sha256, secret, body) |> Base.encode16(case: :lower)

        if Plug.Crypto.secure_compare(calculated_signature, signature) do
          Logger.info("GitHub Webhook signature verified")
          conn
        else
          Logger.error("Unable to verify GitHub Webhook signature")

          conn
          |> send_resp(:bad_request, "Signature failed")
          |> halt()
        end

      [] ->
        Logger.warning("GitHub Webhook missing signature header")

        conn
        |> send_resp(:bad_request, "Missing signature")
        |> halt()

      _ ->
        Logger.error("GitHub Webhook invalid signature format")

        conn
        |> send_resp(:bad_request, "Invalid signature format")
        |> halt()
    end
  end

  def call(conn, _), do: conn
end
