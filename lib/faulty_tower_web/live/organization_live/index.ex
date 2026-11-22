defmodule FaultyTowerWeb.OrganizationLive.Index do
  use FaultyTowerWeb, :live_view

  alias FaultyTower.Organization

  on_mount {FaultyTowerWeb.UserAuth, :ensure_admin}

  @impl true
  def mount(_params, _session, socket) do
    organizations = Organization.list(:projects)

    {:ok, assign(socket, :organizations, organizations)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex items-baseline gap-4">
      <h1 class="text-2xl font-semibold [text-wrap:balance]">Organizations</h1>
      <.link navigate={~p"/organizations/new"} class="text-sm text-zinc-500 hover:text-zinc-900">
        New organization
      </.link>
    </div>
    <div id="organizations" class="mt-4 border-t border-gray-200 [text-wrap:balance]">
      <div :for={organization <- @organizations} :key={organization.id}>
        <div
          id={"org-#{organization.id}"}
          class="flex flex-wrap items-baseline justify-between gap-x-4 border-b border-gray-200 py-2"
        >
          <span class="font-semibold text-zinc-900">{organization.name}</span>
          <span class="flex gap-4 text-sm text-zinc-500">
            <.link navigate={~p"/organizations/#{organization.id}/edit"} class="hover:text-zinc-900">
              Edit
            </.link>
            <.link navigate={~p"/project/#{organization.id}/new"} class="hover:text-zinc-900">
              Add project
            </.link>
          </span>
        </div>
        <.link
          :for={project <- organization.projects}
          :key={project.id}
          id={"project-#{project.id}"}
          navigate={~p"/project/#{project.id}/edit"}
          class="group block border-b border-gray-200 py-2 text-sm sm:grid sm:grid-cols-[1fr_1fr] sm:gap-4"
        >
          <span class="block text-zinc-900 group-hover:underline">{project.name}</span>
          <span class="block text-zinc-500">{project.otp_app || "-"}</span>
        </.link>
        <p
          :if={organization.projects == []}
          id={"org-#{organization.id}-empty"}
          class="border-b border-gray-200 py-2 text-sm text-zinc-500"
        >
          No projects
        </p>
      </div>
    </div>
    """
  end
end
