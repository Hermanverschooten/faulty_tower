# FaultyTower

This is the companion website to the [Faulty](https://hexdocs.pm/faulty/readme.html) error tracking Hex package.

It allows you to create users, organizations and projects within these organizations.
Each project has a name, OTP application name, a generated project key, and can reference Github repo, branch, ...

The Github integration allows you to easily create/resolve/close/reopen issues.

Notification will be sent by e-mail or via Ntfy if configured.

A notification will be sent once for any new error within a 6-hour timeframe.

## Environment variables

| Variable | Explanation |
| -------- | ----------- |
| PHX_SERVER | when this variable is present, Phoenix will start as a server |
| ECTO_IPV6 | enables IPv6 for Ecto |
| DATABASE_URL | the url to access the database |
| SECRET_KEY_BASE | secret used to encrypt various things within Phoenix |
| POOL_SIZE | database connection pool size (default: 10) |
| DNS_CLUSTER_QUERY | DNS query for cluster discovery |
| SITE_ENCRYPT_DB | folder for SiteEncrypt certificate storage (default: tmp/site_encrypt_db) |
| CERT_MODE | certificate mode: "local" for self-signed or "production" for Let's Encrypt |
| NTFY_PASSWORD | the password needed to send messages over Ntfy |
| GH_CLIENT_ID | GitHub App client ID |
| GH_CLIENT_SECRET | GitHub App client secret for webhook verification |
| GH_PRIVATE_KEY | path to the GitHub App private key file |
| FORGEJO_URL | Forgejo instance URL (enables Forgejo integration) |
| FORGEJO_ACCESS_TOKEN | Forgejo access token for API calls |


## MCP Server

FaultyTower includes an MCP (Model Context Protocol) server that allows AI assistants like Claude to interact with your error tracking data. See [MCP_SERVER.md](MCP_SERVER.md) for setup and usage.

## Getting Started

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix
