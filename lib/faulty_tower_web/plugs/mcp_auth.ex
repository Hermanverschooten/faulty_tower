defmodule FaultyTowerWeb.Plugs.MCPAuth do
  import Plug.Conn
  alias FaultyTower.Authentication

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, user} <- authenticate_token(token) do
      assign(conn, :current_user, user)
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> put_resp_content_type("application/json")
        |> send_resp(401, Jason.encode!(%{error: "Unauthorized"}))
        |> halt()
    end
  end

  defp authenticate_token(token) do
    # Try to decode base64 token first, fall back to raw token
    decoded_token =
      case Base.decode64(token) do
        {:ok, decoded} -> decoded
        :error -> token
      end

    case Authentication.get_user_by_session_token(decoded_token) do
      nil -> {:error, :invalid_token}
      user -> {:ok, user}
    end
  end
end
