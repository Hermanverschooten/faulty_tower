defmodule FaultyTowerWeb.DashboardLive do
  alias FaultyTower.Project
  alias FaultyTower.Dashboard
  use FaultyTowerWeb, :live_view

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
        class={[
          "border pt-4 px-0 rounded-md drop-shadow-lg",
          if(project.unresolved_errors == [], do: "bg-white", else: "bg-red-50")
        ]}
      >
        <h2 class="text-2xl font-semibold px-4 mt-2">{project.name}</h2>
        <h2 class={["border-b my-2", if(project.unresolved_errors != [], do: "border-b-red-200")]}>
        </h2>
        <div class="flex flex-col my-2 gap-4 p-4">
          <div class="uppercase text-xs">{project.organization.name}</div>
          <div class="flex justify-between items-center">
            <.link
              navigate={~p"/project/#{project.key}"}
              class={[
                "border rounded-md px-4 py-1 flex items-center gap-2",
                if(project.unresolved_errors == [],
                  do: "text-gray-400 hover:bg-gray-100",
                  else: "text-red-700 border-red-700 hover:bg-red-200"
                )
              ]}
            >
              {errors(project.unresolved_errors)}
            </.link>
            <.link navigate={~p"/project/#{project.id}/edit"}>
              <button class={[
                "rounded-md px-4 py-1 flex items-center gap-1 text-red-700 border-red-700",
                if(project.unresolved_errors == [],
                  do: "hover:bg-red-50",
                  else: "hover:bg-red-200"
                )
              ]}>
                <.icon name="hero-cog" class="w-4 h-4" /> Settings
              </button>
            </.link>
          </div>
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
    |> then(fn %{projects: projects} -> Enum.sort(projects, Project) end)
  end

  defp errors([]), do: "No Errors"
  defp errors([_]), do: "1 Error"

  defp errors(errors) do
    "#{length(errors)} Errors"
  end
end
