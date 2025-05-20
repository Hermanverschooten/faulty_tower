defmodule FaultyTower.Ntfy do
  def send(msg) when is_binary(msg) do
    password = System.get_env("NTFY_PASSWORD")
    url = System.get_env("NTFY_URL")

    if url, do: Req.post(url, auth: {:basic, password}, body: msg)
  end

  def send(msg) when is_map(msg) do
    password = System.get_env("NTFY_PASSWORD")
    url = System.get_env("NTFY_URL")

    if url,
      do:
        Req.post(url,
          auth: {:basic, password},
          json: %{
            topic: "faulty-#{msg.topic}",
            priority: Map.get(msg, :priority, 5),
            tags: Map.get(msg, :tags, ["warning"]),
            title: msg.title,
            message: msg.message,
            actions:
              Map.get(msg, :actions, [
                %{
                  action: "view",
                  label: "Open site",
                  url: FaultyTowerWeb.Endpoint.url(),
                  clear: true
                }
              ])
          }
        )
  end
end
