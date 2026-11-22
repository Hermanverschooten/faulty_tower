# Changelog

All notable changes to this project are documented in this file.

## Unreleased

- Multi-provider issue tracking: projects can create issues in GitHub or Forgejo
  (`git_provider`), with per-organization Forgejo settings (instance URL, access
  token, webhook secret) and optional global Forgejo defaults via `FORGEJO_URL`
  and `FORGEJO_ACCESS_TOKEN`
- Webhook signature verification for Forgejo
- Unified MCP `create_issue` and `assign_issue` tools that dispatch on the
  project's provider (replacing the GitHub-only issue tool); MCP
  `assign_issue` allows attaching an existing issue to an error
- MCP authentication now uses a dedicated `mcp_token` per user, which an
  admin can generate from the user settings page; `MCP_SERVER.md` documents
  the flow
- Error reports containing null bytes are stored safely; the error page
  displays the full occurrence context without truncation
- Error list supports filtering by status and shows per-status counts
- Users created by an admin receive a welcome email, and email
  confirmation/reset links show their validity period
- PWA support (manifest, icons, modern favicon set)
- Redesigned UI with Tailwind CSS 4
- Removes the licensed `phx_2_ban` package; the public copy no longer
  includes its brute-force protection or dashboard page
- Declares `req` as a direct dependency and adds `remote_ip` (proxies are
  configured with the `TRUSTED_PROXIES` environment variable)
- Adds a GitHub Actions test workflow

## 2025-06-25

- Initial public release: error recording and dashboard, GitHub issue
  creation, MCP server, session-token MCP authentication
