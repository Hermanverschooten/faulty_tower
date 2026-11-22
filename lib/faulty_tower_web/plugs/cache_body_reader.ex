defmodule FaultyTowerWeb.Plugs.CacheBodyReader do
  @moduledoc """
  A custom body reader that caches the raw body for webhook signature verification.

  The raw body is stored in conn.assigns[:raw_body] and can be used by
  signature verification plugs before Plug.Parsers consumes it.
  """

  def read_body(conn, opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, opts)
    conn = update_in(conn.assigns[:raw_body], &((&1 || "") <> body))
    {:ok, body, conn}
  end
end
