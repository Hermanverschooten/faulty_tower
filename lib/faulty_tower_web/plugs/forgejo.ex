defmodule FaultyTowerWeb.Plugs.Forgejo do
  @moduledoc """
  Plug for verifying Forgejo webhook signatures.

  This plug verifies that incoming webhook requests from Forgejo have a valid
  HMAC-SHA256 signature using the webhook secret configured for the organization.
  """
  @behaviour Plug

  import Plug.Conn
  import Ecto.Query

  alias FaultyTower.Repo

  require Logger

  def init(config), do: config

  def call(%{request_path: "/api/forgejo/webhook"} = conn, _) do
    body = conn.assigns[:raw_body] || ""

    with {:ok, secret} <- get_webhook_secret(body),
         :ok <- verify_signature(conn, body, secret) do
      conn
    else
      {:error, :no_signature} ->
        Logger.warning("Forgejo Webhook missing signature header")
        conn |> send_resp(:bad_request, "Missing signature") |> halt()

      {:error, :invalid_signature} ->
        Logger.error("Unable to verify Forgejo Webhook signature")
        conn |> send_resp(:bad_request, "Signature failed") |> halt()

      {:error, :organization_not_found} ->
        Logger.warning("Forgejo Webhook organization not found")
        conn |> send_resp(:not_found, "Organization not found") |> halt()

      {:error, :no_webhook_secret} ->
        Logger.warning("Forgejo Webhook secret not configured for organization")
        conn |> send_resp(:bad_request, "Webhook secret not configured") |> halt()

      {:error, reason} ->
        Logger.error("Forgejo Webhook error: #{inspect(reason)}")
        conn |> send_resp(:bad_request, "Error") |> halt()
    end
  end

  def call(conn, _), do: conn

  defp verify_signature(conn, body, secret) do
    case get_req_header(conn, "x-forgejo-signature") do
      [signature] ->
        calculated = :crypto.mac(:hmac, :sha256, secret, body) |> Base.encode16(case: :lower)

        if Plug.Crypto.secure_compare(calculated, signature) do
          Logger.info("Forgejo Webhook signature verified")
          :ok
        else
          {:error, :invalid_signature}
        end

      [] ->
        {:error, :no_signature}
    end
  end

  defp get_webhook_secret(body) do
    with {:ok, payload} <- Jason.decode(body),
         repo_name when is_binary(repo_name) <- get_in(payload, ["repository", "full_name"]),
         {:ok, organization} <- find_organization_by_repo(repo_name),
         %{forgejo: %{webhook_secret: secret}} when is_binary(secret) <- organization do
      {:ok, secret}
    else
      nil -> {:error, :no_webhook_secret}
      %{forgejo: nil} -> {:error, :no_webhook_secret}
      %{forgejo: %{webhook_secret: nil}} -> {:error, :no_webhook_secret}
      {:error, :not_found} -> {:error, :organization_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp find_organization_by_repo(repo_name) do
    query =
      from(p in Schema.Project,
        join: o in assoc(p, :organization),
        where: p.git_provider == "forgejo",
        where:
          fragment(
            "?->>'repo' = ? or ?->>'issue_repo' = ?",
            p.repository,
            ^repo_name,
            p.repository,
            ^repo_name
          ),
        select: o,
        limit: 1
      )

    case Repo.one(query) do
      nil -> {:error, :not_found}
      organization -> {:ok, organization}
    end
  end
end
