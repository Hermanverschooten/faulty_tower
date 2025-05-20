import Config

if System.get_env("PHX_SERVER") do
  config :faulty_tower, FaultyTowerWeb.Endpoint, server: true
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :faulty_tower, FaultyTower.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host =
    System.get_env("HOST_URL") || "example.org"

  config :faulty_tower, :domains, [host]
  config :faulty_tower, :emails, ["me@example.org"]
  config :faulty_tower, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :faulty_tower, FaultyTowerWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: 80
    ],
    https: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      cipher_suite: :strong,
      port: 443
    ],
    secret_key_base: secret_key_base

  config :faulty_tower, FaultyTower.Mailer,
    relay: "localhost",
    adapter: Swoosh.Adapters.SMTP,
    port: 25,
    tls: :if_available,
    allowed_tls_versions: [:tlsv1, :"tlsv1.1", :"tlsv1.2"],
    ssl: false,
    retries: 1,
    no_mx_lookups: true,
    hostname: host
end
