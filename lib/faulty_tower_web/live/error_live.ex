defmodule FaultyTowerWeb.ErrorLive do
  alias FaultyTower.Forgejo
  alias FaultyTower.Github
  alias FaultyTower.Errors
  alias FaultyTower.Project
  use FaultyTowerWeb, :live_view
  import FaultyTowerWeb.Helpers

  @popover_limit 50

  def mount(%{"project" => project_id, "id" => id}, _session, socket) do
    socket =
      with {:ok, project} <- Project.find(project_id, socket.assigns.current_user, :organization),
           {:ok, error} <- Errors.fetch(project.id, id) do
        if connected?(socket) do
          Phoenix.PubSub.subscribe(FaultyTower.PubSub, "error:#{id}")
        end

        socket
        |> assign(:project, project)
        |> assign(:forgejo_url, Forgejo.instance_url(project.organization))
        |> assign(:error, error)
        |> assign(:occurrence_id, nil)
        |> assign(:app_only, false)
      else
        {:error, :not_found} ->
          socket
          |> put_flash(:error, "Error not found")
          |> push_navigate(to: ~p"/project/#{project_id}")
      end

    {:ok, socket}
  end

  def handle_params(params, _uri, %{assigns: %{error: _}} = socket) do
    {:noreply,
     socket
     |> assign(:occurrence_id, params["occurrence"])
     |> assign_occurrence()}
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  # Loads the viewed occurrence (the requested one, else the newest) with its
  # position, neighbours and the newest occurrences for the popover.
  defp assign_occurrence(socket) do
    %{error: error, occurrence_id: occurrence_id} = socket.assigns
    occurrence = Errors.get_occurrence(error.id, occurrence_id)
    {newer, older} = Errors.occurrence_neighbours(occurrence)

    socket
    |> assign(:occurrence, occurrence)
    |> assign(:occurrence_id, occurrence.id)
    |> assign(:position, Errors.occurrence_position(occurrence))
    |> assign(:newer_id, newer)
    |> assign(:older_id, older)
    |> assign(:recent, Errors.recent_occurrences(error.id, @popover_limit))
  end

  def render(assigns) do
    ~H"""
    <div class="text-sm text-zinc-500">
      <.link navigate={~p"/project/#{@project.key}"} class="hover:text-zinc-900 hover:underline">
        {@project.organization.name} / {@project.name}
      </.link>
    </div>
    <h1 class="mt-1 text-2xl font-semibold break-words">{@error.reason}</h1>
    <div class="text-sm text-zinc-500">{sanitize_module(@error.kind)} · #{@error.id}</div>

    <div class="mt-6 grid grid-cols-[1fr_auto] items-center gap-y-4 sm:w-fit">
      <dl
        id="error-header"
        class="col-span-2 grid grid-cols-2 sm:grid-cols-4 gap-x-8 gap-y-3 text-sm"
      >
        <div>
          <dt class="text-xs text-zinc-400">Status</dt>
          <dd>
            <span :if={@error.status == :unresolved} class="text-red-700">unresolved</span>
            <span :if={@error.status == :resolved} class="text-emerald-700/70">resolved</span>
          </dd>
        </div>
        <div>
          <dt class="text-xs text-zinc-400">First seen</dt>
          <dd>
            <.relative_time
              id={"first-seen-#{unix(@error.inserted_at)}"}
              at={@error.inserted_at}
              format="exact"
            />
          </dd>
        </div>
        <div>
          <dt class="text-xs text-zinc-400">Last seen</dt>
          <dd>
            <.relative_time
              id={"last-seen-#{unix(@error.last_occurrence_at)}"}
              at={@error.last_occurrence_at}
              format="exact"
            />
          </dd>
        </div>
        <div>
          <dt class="text-xs text-zinc-400">Issue</dt>
          <dd id="issue">
            <.link
              :if={@error.gh_issue && @error.git_provider == "forgejo"}
              href={"#{@forgejo_url}/#{Forgejo.issues_repo(@project)}/issues/#{@error.gh_issue}"}
              target="_blank"
              class="hover:underline"
            >
              Forgejo #{@error.gh_issue}
            </.link>
            <.link
              :if={@error.gh_issue && @error.git_provider != "forgejo"}
              href={"https://github.com/#{Github.issues_repo(@project)}/issues/#{@error.gh_issue}"}
              target="_blank"
              class="hover:underline"
            >
              GitHub #{@error.gh_issue}
            </.link>
            <button
              :if={!@error.gh_issue && create_provider(@project) == :github}
              type="button"
              class="text-zinc-500 hover:text-zinc-900"
              phx-click="create-github-issue"
            >
              Create issue
            </button>
            <button
              :if={!@error.gh_issue && create_provider(@project) == :forgejo}
              type="button"
              class="text-zinc-500 hover:text-zinc-900"
              phx-click="create-forgejo-issue"
            >
              Create issue
            </button>
            <span :if={!@error.gh_issue && !create_provider(@project)} class="text-zinc-400">–</span>
          </dd>
        </div>
      </dl>
      <div class="col-[1/-1] row-start-2 h-full rounded-md border border-gray-200 bg-white"></div>
      <button
        :if={@error.status == :unresolved}
        type="button"
        class="col-start-2 row-start-2 justify-self-end pr-3 text-sm text-zinc-500 underline decoration-zinc-300 underline-offset-4 hover:text-zinc-900"
        phx-click="resolve"
        phx-value-error_id={@error.id}
      >
        Resolve
      </button>
      <button
        :if={@error.status == :resolved}
        type="button"
        class="col-start-2 row-start-2 justify-self-end pr-3 text-sm text-zinc-500 underline decoration-zinc-300 underline-offset-4 hover:text-zinc-900"
        phx-click="unresolve"
        phx-value-error_id={@error.id}
      >
        Reopen
      </button>
      <div
        id="stepper"
        style="anchor-name: --occurrences"
        class="col-start-1 row-start-2 flex items-center gap-1 px-2 py-2 text-sm"
      >
        <.stepper_arrow
          id="occurrence-newer"
          to={@newer_id && ~p"/project/#{@project.key}/#{@error.id}/#{@newer_id}"}
          label="Newer occurrence"
          glyph="‹"
        />
        <span id="occurrence-position" class="text-zinc-700">
          Occurrence {@position} of {@error.count}
        </span>
        <.stepper_arrow
          id="occurrence-older"
          to={@older_id && ~p"/project/#{@project.key}/#{@error.id}/#{@older_id}"}
          label="Older occurrence"
          glyph="›"
        />
        <button
          type="button"
          popovertarget="occurrences-menu"
          class="ml-2 text-zinc-500 underline decoration-zinc-300 underline-offset-4 hover:text-zinc-900 cursor-pointer"
        >
          List
        </button>
        <div
          id="occurrences-menu"
          popover
          style="position-anchor: --occurrences; position-area: bottom span-right"
          class="inset-auto m-0 mt-1 max-h-80 w-72 max-w-[calc(100vw-2rem)] overflow-y-auto rounded-md border border-gray-200 bg-white p-3 text-sm shadow-sm"
        >
          <ul class="flex flex-col gap-2">
            <li :for={occ <- @recent} class="flex items-baseline gap-2">
              <.link
                patch={~p"/project/#{@project.key}/#{@error.id}/#{occ.id}"}
                data-occurrence={occ.id}
                data-current={occ.id == @occurrence.id}
                class={[
                  "flex flex-1 flex-wrap gap-x-2 hover:underline",
                  (occ.id == @occurrence.id && "text-zinc-900 font-medium") || "text-zinc-700"
                ]}
              >
                <.relative_time id={"occ-time-#{occ.id}"} at={occ.inserted_at} format="exact" />
              </.link>
              <span :if={occ.id == @occurrence.id} class="text-xs text-zinc-400">current</span>
            </li>
          </ul>
          <div
            :if={@error.count > length(@recent)}
            id="occurrences-capped"
            class="mt-2 text-xs text-zinc-400"
          >
            showing {length(@recent)} of {@error.count}
          </div>
        </div>
      </div>
    </div>

    <section class="mt-8">
      <h2 class="text-xs text-zinc-400">Message</h2>
      <pre id="message" class="mt-1 font-mono text-sm whitespace-pre-wrap break-words">{@occurrence.reason}</pre>
    </section>

    <section :if={has_source_info?(@error)} class="mt-6">
      <h2 class="text-xs text-zinc-400">Source</h2>
      <pre id="source" class="mt-1 font-mono text-sm whitespace-pre-wrap break-words">{sanitize_module(@error.source_function)} {@error.source_line}</pre>
    </section>

    <section class="mt-6">
      <div class="flex items-center gap-3">
        <h2 class="text-xs text-zinc-400">Stacktrace</h2>
        <button
          type="button"
          id="toggle-app-frames"
          phx-click="toggle-app-frames"
          class="text-xs text-zinc-500 underline"
        >
          {if @app_only, do: "Show all frames", else: "Show only app frames"}
        </button>
      </div>
      <div id="stacktrace" class="mt-1 font-mono text-xs sm:text-sm">
        <div
          :for={{line, index} <- frames(@occurrence, @project, @app_only)}
          :key={index}
          data-frame={if app_frame?(line, @project), do: "app", else: "lib"}
          class={[
            "flex gap-3 py-0.5",
            (app_frame?(line, @project) && "text-zinc-900") || "text-zinc-400"
          ]}
        >
          <span class="w-16 shrink-0 break-words text-zinc-400">{line.application || "–"}</span>
          <div class="min-w-0 flex-1">
            <div :if={line.module} class="break-words">
              {line.module}.{line.function}/{line.arity}
            </div>
            <div :if={line.file} class="break-words">
              {line.file}:{line.line}<.gh_link
                :if={app_frame?(line, @project)}
                project={@project}
                line={line}
                forgejo_url={@forgejo_url}
              />
            </div>
            <div :if={!line.file}>(no location)</div>
          </div>
        </div>
      </div>
    </section>

    <section class="mt-6">
      <h2 class="text-xs text-zinc-400">Context</h2>
      <pre
        id="context"
        class="mt-1 font-mono text-xs sm:text-sm whitespace-pre-wrap break-words"
      ><%= inspect(@occurrence.context, pretty: true, limit: :infinity, printable_limit: :infinity) %></pre>
    </section>
    """
  end

  defp frames(occurrence, project, app_only) do
    occurrence.stacktrace.lines
    |> Enum.with_index()
    |> Enum.filter(fn {line, _} -> !app_only or app_frame?(line, project) end)
  end

  defp app_frame?(line, project), do: line.application == project.otp_app

  defp create_provider(project) do
    cond do
      project.git_provider == "github" && Github.issues_repo(project) -> :github
      Forgejo.configured?(project) -> :forgejo
      true -> nil
    end
  end

  attr :project, :any, required: true
  attr :line, :string, required: true
  attr :forgejo_url, :string, required: true

  def gh_link(assigns) do
    ~H"""
    <.link
      :if={
        @project.git_provider == "github" && @project.repository &&
          @project.otp_app == @line.application
      }
      href={"https://github.com/#{@project.repository.repo}/tree/#{@project.repository.branch || "main"}/#{@line.file}#L#{@line.line}"}
      target="_blank"
    >
      <.icon name="hero-link" class="ml-1 h-4 w-4" />
    </.link>
    <.link
      :if={
        @project.git_provider == "forgejo" && @project.repository &&
          @project.otp_app == @line.application
      }
      href={"#{@forgejo_url}/#{@project.repository.repo}/src/branch/#{@project.repository.branch || "main"}/#{@line.file}#L#{@line.line}"}
      target="_blank"
    >
      <.icon name="hero-link" class="ml-1 h-4 w-4" />
    </.link>
    """
  end

  attr :id, :string, required: true
  attr :to, :string, default: nil
  attr :label, :string, required: true
  attr :glyph, :string, required: true

  defp stepper_arrow(assigns) do
    ~H"""
    <.link
      :if={@to}
      id={@id}
      patch={@to}
      aria-label={@label}
      class="inline-block w-5 text-center text-zinc-700 hover:text-zinc-900"
    >
      {@glyph}
    </.link>
    <span
      :if={!@to}
      id={@id}
      aria-disabled="true"
      class="inline-block w-5 text-center text-zinc-300"
    >
      {@glyph}
    </span>
    """
  end

  def handle_event("toggle-app-frames", _params, socket) do
    {:noreply, update(socket, :app_only, &(!&1))}
  end

  def handle_event("resolve", _params, socket) do
    %{project: project, error: error, current_user: current_user} = socket.assigns

    socket =
      with {:ok, error} <- Errors.resolve(project.id, error.id, :resolved) do
        sync = Errors.sync_issue(project, error, current_user, :resolved)

        Phoenix.PubSub.broadcast(FaultyTower.PubSub, "error:#{error.id}", :refresh)

        Phoenix.PubSub.broadcast(
          FaultyTower.PubSub,
          "project:#{project.key}",
          {:refresh, error.id}
        )

        sync_flash(socket, sync, "Resolved, but closing the issue failed")
      else
        {:error, :not_found} -> socket
      end

    {:noreply, socket}
  end

  def handle_event("unresolve", _params, socket) do
    %{project: project, error: error, current_user: current_user} = socket.assigns

    socket =
      with {:ok, error} <- Errors.resolve(project.id, error.id, :unresolved) do
        sync = Errors.sync_issue(project, error, current_user, :unresolved)

        Phoenix.PubSub.broadcast(FaultyTower.PubSub, "error:#{error.id}", :refresh)

        Phoenix.PubSub.broadcast(
          FaultyTower.PubSub,
          "project:#{project.key}",
          {:refresh, error.id}
        )

        sync_flash(socket, sync, "Reopened, but reopening the issue failed")
      else
        {:error, :not_found} -> socket
      end

    {:noreply, socket}
  end

  def handle_event("create-github-issue", _params, socket) do
    %{error: error} = socket.assigns

    case Errors.create_github_issue(error) do
      {:ok, number} ->
        socket
        |> put_flash(:info, "GitHub Issue ##{number} created")

      {:error, _reason} ->
        socket
        |> put_flash(:error, "Failed to create GitHub issue")
    end
    |> noreply()
  end

  def handle_event("create-forgejo-issue", _params, socket) do
    %{error: error} = socket.assigns

    case Errors.create_forgejo_issue(error) do
      {:ok, number} ->
        socket
        |> put_flash(:info, "Forgejo Issue ##{number} created")

      {:error, _reason} ->
        socket
        |> put_flash(:error, "Failed to create Forgejo issue")
    end
    |> noreply()
  end

  def handle_info(:refresh, socket) do
    socket =
      with {:ok, error} <- Errors.fetch(socket.assigns.project.id, socket.assigns.error.id) do
        socket |> assign(:error, error) |> assign_occurrence()
      else
        {:error, :not_found} ->
          socket
          |> put_flash(:error, "Error disappeared")
          |> push_navigate(to: ~p"/project/#{socket.assigns.project.key}")
      end

    {:noreply, socket}
  end
end
