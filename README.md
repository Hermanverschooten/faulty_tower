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
| HOST_URL | the url the site is hosted on, will be used by Phoenix, SitEncrypt and Swoosh |
| NTFY_PASSWORD | the password needed to send messages over Ntfy |
| NTFY_URL | the Ntfy service to use, if not set no messages will be sent |


To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`
  * Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.
  * Use the forgotten password with `admin@example.org` and check the `/dev/mailbox` page to continue.


Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix
