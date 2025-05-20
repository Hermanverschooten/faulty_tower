defmodule FaultyTowerWeb.ErrorLive do
  alias FaultyTower.Github
  alias FaultyTower.Errors
  alias FaultyTower.Project
  use FaultyTowerWeb, :live_view
  import FaultyTowerWeb.Helpers

  def mount(%{"project" => project_id, "id" => id}, _session, socket) do
    socket =
      with {:ok, project} <- Project.find(project_id, socket.assigns.current_user, :organization),
           {:ok, error} <- Errors.fetch(id, :occurrences) do
        occurrences =
          error.occurrences
          |> Enum.map(&{format_datetime(&1.inserted_at), &1.id})

        [occurrence | _] = error.occurrences

        if connected?(socket) do
          Phoenix.PubSub.subscribe(FaultyTower.PubSub, "error:#{id}")
        end

        socket
        |> assign(:project, project)
        |> assign(:occurrence, occurrence)
        |> assign(:error, error)
        |> assign(:occurrences, occurrences)
        |> assign(:show_only, false)
      else
        {:error, :not_found} ->
          socket
          |> put_flash(:error, "Error not found")
          |> push_navigate(to: ~p"/project/#{project_id}")
      end

    {:ok, socket}
  end

  def handle_params(%{"occurrence" => occurrence_id}, uri, socket) do
    case Enum.find(
           socket.assigns.error.occurrences,
           &(to_string(&1.id) == to_string(occurrence_id))
         ) do
      nil ->
        handle_params(%{}, uri, socket)

      occurrence ->
        {:noreply, socket |> assign(:occurrence, occurrence)}
    end
  end

  def handle_params(_params, _uri, socket) do
    [occurrence | _] = socket.assigns.error.occurrences
    {:noreply, socket |> assign(:occurrence, occurrence)}
  end

  def render(assigns) do
    ~H"""
    <.link
      navigate={~p"/project/#{@project.key}"}
      class="hover:text-blue-700 bg-gray-400 flex items-center p-2"
    >
      <.icon name="hero-chevron-double-left" class="w-3 h-3 mr-1" /> Back to list
    </.link>
    <h1 class="text-2xl font-semibold bg-gray-200 px-4 py-4 uppercase">
      {@project.organization.name} - {@project.name}
    </h1>
    <div class="bg-gray-100 lg:p-4 text-gray-600">
      <div class="uppercase font-bold">
        Error #{@error.id} @ {format_datetime(@error.last_occurrence_at)}
      </div>
      <h1 class="text-2xl font-semibold whitespace-nowrap text-ellipsis w-full overflow-hidden">
        ({sanitize_module(@error.kind)}) {@error.reason}
      </h1>

      <div class="p-1 my-2 bg-gray-400 lg:p-4 grid grid-cols-1 lg:grid-cols-4 gap-2">
        <div class="col-span-3">
          <div class="text-gray-700 font-bold">FULL MESSAGE</div>
          <div class="p-4 rounded-md bg-gray-600 text-white mb-4 mt-2 overflow-x-scroll">
            {@occurrence.reason}
          </div>
          <div class="text-gray-700 font-bold">SOURCE</div>
          <div class="p-4 rounded-md bg-gray-600 text-white mb-4 mt-2 overflow-x-scroll">
            <p :if={has_source_info?(@error)} class="font-normal">
              {sanitize_module(@error.source_function)}
              <br />
              {@error.source_line}
            </p>
          </div>
          <div class="text-gray-700 font-bold">STACKTRACE</div>
          <div class="p-4 rounded-md bg-gray-600 text-white mb-4 mt-2 overflow-x-scroll">
            <div class="justify-center lg:justify-end flex items-center pb-4 lg:pb-0">
              <label>
                <input
                  type="checkbox"
                  class="bg-gray-600 rounded"
                  checked={@show_only}
                  phx-click="toggle-show"
                /> Show only app frames
              </label>
            </div>
            <table class="overflow-x-scroll table-fixed text-xs lg:text-base">
              <tr :for={line <- filter(@occurrence.stacktrace.lines, @project.otp_app, @show_only)}>
                <td class="align-top px-2">({line.application || "none"})</td>
                <td>
                  <div :if={line.module} class="text-nowrap">
                    {line.module}.{line.function}/{line.arity}
                  </div>
                  <div :if={line.file} class="text-nowrap">
                    {line.file}:{line.line}<.gh_link project={@project} line={line} />
                  </div>
                  <div :if={!line.file} class="text-nowrap">(no location)</div>
                </td>
              </tr>
            </table>
          </div>
          <div class="text-gray-700 font-bold">CONTEXT</div>
          <pre class="text-xs lg:text-base p-4 rounded-md bg-gray-600 text-white mb-4 mt-2 overflow-x-scroll"><%= inspect(@occurrence.context, pretty: true) %></pre>
        </div>
        <div class="border-t-2 py-4 lg:border-t-0 lh:py-0 lg:border-l-2 lg:px-4 border-gray-600">
          <div class="text-gray-700 font-bold">OCCURRENCES ({@error.count} TOTAL)</div>
          <form for={} id="occurrence-selector-form" phx-change="select-occurrence">
            <select
              id="occurrence-selector"
              name="occurrence"
              class="mt-2 rounded bg-gray-600 text-white border-gray-300"
            >
              {Phoenix.HTML.Form.options_for_select(@occurrences, @occurrence.id)}
            </select>
          </form>
          <div class="text-gray-700 font-bold mt-4">ERROR KIND</div>
          <div class="text-white font-bold">{sanitize_module(@error.kind)}</div>
          <div class="text-gray-700 font-bold mt-4">LAST SEEN</div>
          <div class="text-white font-bold">{format_datetime(@error.last_occurrence_at)}</div>
          <div class="text-gray-700 font-bold mt-4">FIRST SEEN</div>
          <div class="text-white font-bold">{format_datetime(@error.inserted_at)}</div>
          <div class="text-gray-700 font-bold mt-4">STATUS</div>

          <div class="mt-2 mb-4">
            <.badge :if={@error.status == :resolved} color={:green}>Resolved</.badge>
            <.badge :if={@error.status == :unresolved} color={:red}>Unresolved</.badge>
          </div>
          <.button
            :if={@error.status == :unresolved}
            phx-click="resolve"
            phx-value-error_id={@error.id}
          >
            Mark as resolved
          </.button>

          <.button
            :if={@error.status == :resolved}
            phx-click="unresolve"
            phx-value-error_id={@error.id}
          >
            Unmark as resolved
          </.button>
          <.button
            :if={Github.issues_repo(@project) && !@error.gh_issue}
            type="button"
            class="flex items-center hover:font-bold gap-2 mt-2"
            phx-click="create-github-issue"
          >
            <svg viewBox="0 0 24 24" aria-hidden="true" class="size-6 fill-white">
              <path
                fill-rule="evenodd"
                clip-rule="evenodd"
                d="M12 2C6.477 2 2 6.463 2 11.97c0 4.404 2.865 8.14 6.839 9.458.5.092.682-.216.682-.48 0-.236-.008-.864-.013-1.695-2.782.602-3.369-1.337-3.369-1.337-.454-1.151-1.11-1.458-1.11-1.458-.908-.618.069-.606.069-.606 1.003.07 1.531 1.027 1.531 1.027.892 1.524 2.341 1.084 2.91.828.092-.643.35-1.083.636-1.332-2.22-.251-4.555-1.107-4.555-4.927 0-1.088.39-1.979 1.029-2.675-.103-.252-.446-1.266.098-2.638 0 0 .84-.268 2.75 1.022A9.607 9.607 0 0 1 12 6.82c.85.004 1.705.114 2.504.336 1.909-1.29 2.747-1.022 2.747-1.022.546 1.372.202 2.386.1 2.638.64.696 1.028 1.587 1.028 2.675 0 3.83-2.339 4.673-4.566 4.92.359.307.678.915.678 1.846 0 1.332-.012 2.407-.012 2.734 0 .267.18.577.688.48 3.97-1.32 6.833-5.054 6.833-9.458C22 6.463 17.522 2 12 2Z"
              >
              </path>
            </svg>
            Create Issue
          </.button>
          <.link
            :if={@error.gh_issue}
            href={"https://github.com/#{Github.issues_repo(@project)}/issues/#{@error.gh_issue}"}
            target="_blank"
          >
            <.button type="button" class="flex items-center hover:font-bold gap-2 mt-2">
              <svg viewBox="0 0 24 24" aria-hidden="true" class="size-6 fill-white">
                <path
                  fill-rule="evenodd"
                  clip-rule="evenodd"
                  d="M12 2C6.477 2 2 6.463 2 11.97c0 4.404 2.865 8.14 6.839 9.458.5.092.682-.216.682-.48 0-.236-.008-.864-.013-1.695-2.782.602-3.369-1.337-3.369-1.337-.454-1.151-1.11-1.458-1.11-1.458-.908-.618.069-.606.069-.606 1.003.07 1.531 1.027 1.531 1.027.892 1.524 2.341 1.084 2.91.828.092-.643.35-1.083.636-1.332-2.22-.251-4.555-1.107-4.555-4.927 0-1.088.39-1.979 1.029-2.675-.103-.252-.446-1.266.098-2.638 0 0 .84-.268 2.75 1.022A9.607 9.607 0 0 1 12 6.82c.85.004 1.705.114 2.504.336 1.909-1.29 2.747-1.022 2.747-1.022.546 1.372.202 2.386.1 2.638.64.696 1.028 1.587 1.028 2.675 0 3.83-2.339 4.673-4.566 4.92.359.307.678.915.678 1.846 0 1.332-.012 2.407-.012 2.734 0 .267.18.577.688.48 3.97-1.32 6.833-5.054 6.833-9.458C22 6.463 17.522 2 12 2Z"
                >
                </path>
              </svg>
              GitHub Issue
            </.button>
          </.link>
        </div>
      </div>
    </div>
    """
  end

  attr :project, :any, required: true
  attr :line, :string, required: true

  def gh_link(assigns) do
    ~H"""
    <.link
      :if={@project.github && @project.otp_app == @line.application}
      href={"https://github.com/#{@project.github.repo}/tree/#{@project.github.branch}/#{@line.file}#L#{@line.line}"}
      target="_blank"
    >
      <.icon name="hero-link" class="ml-1 h-4 w-4" />
    </.link>
    """
  end

  def handle_event("toggle-show", _params, socket) do
    {:noreply, socket |> assign(:show_only, !socket.assigns.show_only)}
  end

  def handle_event("select-occurrence", %{"occurrence" => occurrence_id}, socket) do
    {:noreply,
     socket
     |> push_patch(
       to: ~p"/project/#{socket.assigns.project.key}/#{socket.assigns.error.id}/#{occurrence_id}"
     )}
  end

  def handle_event("resolve", %{"error_id" => error_id}, socket) do
    socket =
      with :ok <- Errors.resolve(error_id, :resolved) do
        %{project: project, error: error, current_user: current_user} = socket.assigns

        if error.gh_issue, do: Github.close_issue(project, error.gh_issue, current_user)

        Phoenix.PubSub.broadcast(FaultyTower.PubSub, "error:#{socket.assigns.error.id}", :refresh)

        Phoenix.PubSub.broadcast(
          FaultyTower.PubSub,
          "project:#{socket.assigns.project.key}",
          {:refresh, error_id}
        )

        socket
      else
        :error ->
          socket
          |> put_flash(:error, "I could not mark the error as unresolved!")
      end

    {:noreply, socket}
  end

  def handle_event("unresolve", %{"error_id" => error_id}, socket) do
    socket =
      with :ok <- Errors.resolve(error_id, :unresolved) do
        Phoenix.PubSub.broadcast(FaultyTower.PubSub, "error:#{socket.assigns.error.id}", :refresh)

        Phoenix.PubSub.broadcast(
          FaultyTower.PubSub,
          "project:#{socket.assigns.project.key}",
          {:refresh, error_id}
        )

        socket
      else
        :error ->
          socket
          |> put_flash(:error, "I could not mark the error as unresolved!")
      end

    {:noreply, socket}
  end

  def handle_event("create-github-issue", _params, socket) do
    %{error: error, project: project, occurrence: occurrence} = socket.assigns

    with {:ok, number} <-
           Github.create_issue(
             project,
             error,
             occurrence,
             url(~p"/project/#{project.key}/#{error.id}/#{occurrence.id}")
           ),
         :ok <- Errors.set_github_issue(error.id, number) do
      Phoenix.PubSub.broadcast(FaultyTower.PubSub, "error:#{error.id}", :refresh)

      Phoenix.PubSub.broadcast(
        FaultyTower.PubSub,
        "project:#{socket.assigns.project.key}",
        {:refresh, error.id}
      )

      socket
    else
      :error ->
        socket
        |> put_flash(:error, "Failed to create issue")
    end
    |> noreply()
  end

  def handle_info(:refresh, socket) do
    socket =
      with {:ok, error} <- Errors.fetch(socket.assigns.error.id, :occurrences) do
        socket |> assign(:error, error)
      else
        {:error, :not_found} ->
          socket
          |> put_flash(:error, "Error disappeared")
          |> push_navigate(to: ~p"/project/#{socket.assigns.project.key}")
      end

    {:noreply, socket}
  end

  defp filter(lines, _opt_app, false), do: lines

  defp filter(lines, otp_app, true) do
    Enum.filter(lines, &(&1.application == otp_app))
  end
end
