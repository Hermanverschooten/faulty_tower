defmodule FaultyTowerWeb.DashboardLive do
  alias FaultyTower.Dashboard
  use FaultyTowerWeb, :live_view
  import FaultyTowerWeb.Helpers, only: [unix: 1]

  def mount(_params, _session, socket) do
    projects = load_projects(socket.assigns.current_user)

    if connected?(socket) do
      for %{key: project_id} <- projects,
          do: Phoenix.PubSub.subscribe(FaultyTower.PubSub, "project:#{project_id}")
    end

    socket
    |> assign(:projects, projects)
    |> ok()
  end

  def render(assigns) do
    ~H"""
    <div class="grid grid-cols-1  md:grid-cols-2 xl:grid-cols-3 gap-4" id="dashboard">
      <div
        :for={project <- @projects}
        :key={project.id}
        class="relative rounded-md border border-gray-200 bg-white p-4"
      >
        <.link
          navigate={~p"/project/#{project.id}/edit"}
          aria-label="Project settings"
          class="absolute z-10 top-4 right-4 text-zinc-400 hover:text-zinc-700"
        >
          <.icon name="hero-cog" class="w-4 h-4" />
        </.link>
        <h2 class="font-semibold pr-6">
          <.link navigate={~p"/project/#{project.key}"} class="after:absolute after:inset-0">
            {project.name}
          </.link>
        </h2>
        <div class="text-sm text-zinc-500">{project.organization.name}</div>
        <div class="mt-3 text-sm">
          <span :if={project.unresolved_errors != []} class="text-red-700 font-medium">
            {length(project.unresolved_errors)} unresolved
          </span>
          <span :if={project.unresolved_errors == []} class="text-zinc-400">–</span>
        </div>
        <%!-- relative z-10 lifts it above the stretched link so the hover title shows --%>
        <div class="relative z-10 w-fit text-sm text-zinc-500">
          Last error
          <.relative_time
            id={"last-#{project.id}-#{unix(project.last_error_at)}"}
            at={project.last_error_at}
          />
        </div>
      </div>
    </div>
    """
  end

  def handle_info({:refresh, _}, socket) do
    projects = load_projects(socket.assigns.current_user)

    socket
    |> assign(:projects, projects)
    |> noreply()
  end

  def handle_info({:add, _}, socket) do
    projects = load_projects(socket.assigns.current_user)

    socket
    |> assign(:projects, projects)
    |> noreply()
  end

  defp load_projects(current_user) do
    current_user
    |> Dashboard.projects()
    |> Map.fetch!(:projects)
  end
end
