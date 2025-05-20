defmodule FaultyTowerWeb.ErrorsLive do
  use FaultyTowerWeb, :live_view
  alias FaultyTower.Project
  alias FaultyTower.Errors
  alias FaultyTower.Github
  import FaultyTowerWeb.Helpers

  def mount(%{"project" => project_id}, _session, socket) do
    socket =
      with {:ok, project} <- Project.find(project_id, socket.assigns.current_user, :organization) do
        errors =
          load_errors(project.id)

        if connected?(socket) do
          Phoenix.PubSub.subscribe(FaultyTower.PubSub, "project:#{project_id}")
        end

        socket
        |> assign(:project, project)
        |> stream(:errors, errors)
        |> assign(:occurrences, %{})
      else
        {:error, :not_found} ->
          socket
          |> put_flash(:error, "Project not found")
          |> push_navigate(to: ~p"/")
      end

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <h1 class="text-2xl font-semibold bg-gray-200 px-4 py-4 uppercase">
      {@project.organization.name} - {@project.name}
    </h1>

    <table class="w-full text-sm text-left rtl:text-right text-gray-600 table-fixed">
      <thead class="text-xs uppercase bg-gray-900 text-gray-300">
        <tr>
          <th scope="col" class="px-4 pr-2 py-3 w-128">Error</th>
          <th scope="col" class="hidden lg:table-cell px-4 py-3 w-72">Occurrences</th>
          <th scope="col" class="px-4 py-3 w-28">Status</th>
          <th scope="col" class="hidden lg:table-cell px-4 py-3 w-32"></th>
        </tr>
      </thead>
      <tbody id="error-table" phx-update="stream">
        <tr>
          <td :if={@streams.errors == []} colspan="4" class="text-center py-8 font-extralight">
            No errors to show 🎉
          </td>
        </tr>
        <tr
          :for={{dom_id, error} <- @streams.errors}
          class="border-b bg-gray-400/10 border-y border-gray-900 hover:bg-gray-800/60 last-of-type:border-b-0"
          id={dom_id}
        >
          <td scope="row" class="px-4 py-4 font-medium text-black relative">
            <.link navigate={~p"/project/#{@project.key}/#{error.id}"} class="absolute inset-1">
              <span class="sr-only">({sanitize_module(error.kind)}) {error.reason}</span>
            </.link>
            <p class="whitespace-nowrap text-ellipsis w-full overflow-hidden">
              ({sanitize_module(error.kind)}) {error.reason}
            </p>
            <p :if={has_source_info?(error)} class="font-normal">
              {sanitize_module(error.source_function)}
              <br />
              {error.source_line}
            </p>
            <div class="lg:hidden mt-4">
              <p>Last: {format_datetime(error.last_occurrence_at)}</p>
              <p>Total: {error.count}</p>
            </div>
          </td>
          <td class="hidden lg:table-cell px-4 py-4">
            <p>Last: {format_datetime(error.last_occurrence_at)}</p>
            <p>Total: {error.count}</p>
          </td>
          <td class="p-0 text-center lg:p-4">
            <.badge :if={error.status == :resolved} color={:green}>Resolved</.badge>
            <.badge :if={error.status == :unresolved} color={:red}>Unresolved</.badge>
            <div class="lg:hidden mt-4">
              <.button
                :if={error.status == :unresolved}
                phx-click="resolve"
                phx-value-error_id={error.id}
                phx-value-gh_issue={error.gh_issue}
              >
                Resolve
              </.button>

              <.button
                :if={error.status == :resolved}
                phx-click="unresolve"
                phx-value-error_id={error.id}
                phx-value-gh_issue={error.gh_issue}
              >
                Unresolve
              </.button>
            </div>
          </td>
          <td class="hidden lg:table-cell px-4 py-4 text-center">
            <.button
              :if={error.status == :unresolved}
              phx-click="resolve"
              phx-value-error_id={error.id}
              phx-value-gh_issue={error.gh_issue}
            >
              Resolve
            </.button>

            <.button
              :if={error.status == :resolved}
              phx-click="unresolve"
              phx-value-error_id={error.id}
              phx-value-gh_issue={error.gh_issue}
            >
              Unresolve
            </.button>
          </td>
        </tr>
      </tbody>
    </table>
    """
  end

  def handle_event("resolve", %{"error_id" => error_id} = params, socket) do
    socket =
      with :ok <- Errors.resolve(error_id) do
        %{project: project, current_user: current_user} = socket.assigns

        if gh_issue = params["gh_issue"], do: Github.close_issue(project, gh_issue, current_user)

        Phoenix.PubSub.broadcast(FaultyTower.PubSub, "error:#{error_id}", :refresh)

        Phoenix.PubSub.broadcast(
          FaultyTower.PubSub,
          "project:#{socket.assigns.project.key}",
          {:refresh, error_id}
        )

        socket
      else
        :error ->
          socket
          |> put_flash(:error, "Failed to resolve")
      end

    {:noreply, socket}
  end

  def handle_event("unresolve", %{"error_id" => error_id} = params, socket) do
    socket =
      with :ok <- Errors.resolve(error_id, :unresolved) do
        %{project: project, current_user: current_user} = socket.assigns

        if gh_issue = params["gh_issue"], do: Github.reopen_issue(project, gh_issue, current_user)
        Phoenix.PubSub.broadcast(FaultyTower.PubSub, "error:#{error_id}", :refresh)

        Phoenix.PubSub.broadcast(
          FaultyTower.PubSub,
          "project:#{socket.assigns.project.key}",
          {:refresh, error_id}
        )

        socket
      else
        :error ->
          socket
          |> put_flash(:error, "Failed to resolve")
      end

    {:noreply, socket}
  end

  def handle_info({:refresh, error_id}, socket) do
    error = Errors.get(error_id)
    {:noreply, stream_insert(socket, :errors, error)}
  end

  def handle_info({:add, error_id}, socket) do
    error = Errors.get(error_id)
    {:noreply, stream_insert(socket, :errors, error, at: 0)}
  end

  defp load_errors(project_id) do
    project_id
    |> Errors.list()
    |> Enum.sort_by(
      fn err ->
        [
          if(err.status == :unresolved, do: 1, else: 0),
          DateTime.to_unix(err.last_occurrence_at)
        ]
        |> Enum.join(".")
      end,
      :desc
    )
  end
end
