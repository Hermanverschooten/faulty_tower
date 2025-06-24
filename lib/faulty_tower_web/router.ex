defmodule FaultyTowerWeb.Router do
  use FaultyTowerWeb, :router

  import FaultyTowerWeb.UserAuth
  import Phoenix.LiveDashboard.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {FaultyTowerWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :mcp do
    plug :accepts, ["json"]
    plug :fetch_session
    plug FaultyTowerWeb.Plugs.MCPAuth
  end

  scope "/api", FaultyTowerWeb do
    pipe_through :api

    post "/report/:project_id", ReportController, :receive
    post "/gh/webhook", GitHubController, :webhook
  end

  if Application.compile_env(:faulty_tower, :dev_routes) do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", FaultyTowerWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{FaultyTowerWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", FaultyTowerWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{FaultyTowerWeb.UserAuth, :ensure_authenticated}] do
      live "/", DashboardLive
      live "/projects", ProjectLive.Index
      live "/project/:organization_id/new", ProjectLive.New
      live "/project/:project/edit", ProjectLive.Edit
      live "/project/:project", ErrorsLive
      live "/project/:project/:id", ErrorLive
      live "/project/:project/:id/:occurrence", ErrorLive
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email
      live "/users", UserLive
      live "/organizations", OrganizationLive
    end
  end

  scope "/", FaultyTowerWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete

    live_dashboard "/live_dashboard",
      metrics: FaultyTowerWeb.Telemetry,
      additional_pages: [route_name: Phx2Ban.LiveDashboardPlugin],
      on_mount: [{FaultyTowerWeb.UserAuth, :ensure_authenticated}]

    live_session :current_user,
      on_mount: [{FaultyTowerWeb.UserAuth, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end

  scope "/mcp" do
    pipe_through :mcp

    alias FaultyTower.MCPTools

    forward "/", Vancouver.Router,
      tools: [
        MCPTools.ListOrganizations,
        MCPTools.ListProjects,
        MCPTools.ListErrors,
        MCPTools.SearchErrors,
        MCPTools.GetErrorDetails,
        MCPTools.ResolveError,
        MCPTools.ReopenError,
        MCPTools.CreateGithubIssue
      ]
  end
end
