defmodule FaultyTowerWeb.ErrorsLive do
  use FaultyTowerWeb, :live_view
  alias FaultyTower.Project
  alias FaultyTower.Errors
  import FaultyTowerWeb.Helpers

  def mount(%{"project" => project_id}, _session, socket) do
    socket =
      with {:ok, project} <- Project.find(project_id, socket.assigns.current_user, :organization) do
        if connected?(socket) do
          Phoenix.PubSub.subscribe(FaultyTower.PubSub, "project:#{project_id}")
        end

        socket
        |> assign(:project, project)
        |> assign(:occurrences, %{})
      else
        {:error, :not_found} ->
          socket
          |> put_flash(:error, "Project not found")
          |> push_navigate(to: ~p"/")
      end

    {:ok, socket}
  end

  # Without a project (not found) mount already redirected.
  def handle_params(params, _uri, socket) do
    case socket.assigns do
      %{project: project} ->
        status = parse_status(params["status"])

        socket
        |> assign(:status, status)
        |> assign_counts()
        |> stream(:errors, Errors.list(project.id, status), reset: true)
        |> then(&{:noreply, &1})

      _ ->
        {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="text-sm text-zinc-500">{@project.organization.name}</div>
    <h1 class="text-2xl font-semibold">{@project.name}</h1>
    <p id="totals" class="mt-1 text-sm">
      <.total_segment
        status={@status}
        target={:all}
        href={~p"/project/#{@project.key}?status=all"}
        label={pluralize(@counts.total, "error")}
      /> ·
      <.total_segment
        status={@status}
        target={:unresolved}
        href={~p"/project/#{@project.key}"}
        label={"#{@counts.unresolved} unresolved"}
      /> ·
      <.total_segment
        status={@status}
        target={:resolved}
        href={~p"/project/#{@project.key}?status=resolved"}
        label={"#{@counts.resolved} resolved"}
      />
    </p>

    <table class={[
      "mt-6 w-full text-sm text-left text-zinc-600 table-fixed",
      !empty?(@status, @counts) && "max-sm:border-t border-gray-200"
    ]}>
      <thead
        :if={!empty?(@status, @counts)}
        class="hidden sm:table-header-group text-xs text-zinc-400"
      >
        <tr class="border-b border-gray-200">
          <th scope="col" class="py-2 pr-2 font-normal">Error</th>
          <th scope="col" class="py-2 px-2 font-normal w-20 text-right">Count</th>
          <th scope="col" class="py-2 px-2 font-normal w-28 text-right">Last seen</th>
          <th scope="col" class="py-2 pl-2 w-40"><span class="sr-only">Status and action</span></th>
        </tr>
      </thead>
      <tbody id="error-table" phx-update="stream">
        <tr
          :for={{dom_id, error} <- @streams.errors}
          id={dom_id}
          class="relative border-b border-gray-200 hover:bg-gray-50 max-sm:flex max-sm:flex-col"
        >
          <td class="py-3 pr-2 max-sm:pr-0 max-sm:pb-0">
            <p class="truncate font-medium text-black">
              <.link
                navigate={~p"/project/#{@project.key}/#{error.id}"}
                class="after:absolute after:inset-0"
              >
                ({sanitize_module(error.kind)}) {error.reason}
              </.link>
            </p>
            <p class="flex gap-1 text-xs text-zinc-500">
              <span :if={has_source_info?(error)} class="truncate min-w-0">
                {sanitize_module(error.source_function)} {error.source_line}
              </span>
              <span class="sm:hidden shrink-0 whitespace-nowrap">
                <span :if={has_source_info?(error)}>·</span>
                {error.count}× ·
                <.relative_time
                  id={"lastm-#{error.id}-#{unix(error.last_occurrence_at)}"}
                  at={error.last_occurrence_at}
                />
              </span>
            </p>
          </td>
          <td class="hidden sm:table-cell py-3 px-2 text-right tabular-nums">{error.count}×</td>
          <td class="hidden sm:table-cell py-3 px-2 text-right text-zinc-500">
            <.relative_time
              id={"last-#{error.id}-#{unix(error.last_occurrence_at)}"}
              at={error.last_occurrence_at}
            />
          </td>
          <td class="py-3 pl-2 text-right text-xs whitespace-nowrap max-sm:pl-0 max-sm:pt-1 max-sm:flex">
            <span
              :if={show_status?(error, @status) and error.status == :unresolved}
              class="status-word text-red-700 mr-2"
            >
              unresolved
            </span>
            <span
              :if={show_status?(error, @status) and error.status == :resolved}
              class="status-word text-emerald-700/70 mr-2"
            >
              resolved
            </span>
            <button
              :if={error.status == :unresolved}
              type="button"
              class="relative z-10 ml-auto text-zinc-500 hover:text-zinc-900"
              phx-click="resolve"
              phx-value-error_id={error.id}
            >
              Resolve
            </button>
            <button
              :if={error.status == :resolved}
              type="button"
              class="relative z-10 ml-auto text-zinc-500 hover:text-zinc-900"
              phx-click="unresolve"
              phx-value-error_id={error.id}
            >
              Reopen
            </button>
          </td>
        </tr>
      </tbody>
    </table>

    <p :if={empty?(@status, @counts)} id="empty" class="mt-6 text-sm text-zinc-500">
      {empty_text(@status, @counts)}
    </p>
    <p :if={@counts.total == 0} id="api-hint" class="mt-1 text-sm text-zinc-500">
      Report errors with POST to
      <code class="font-mono select-all">{url(~p"/api/report/#{@project.key}")}</code>
    </p>
    """
  end

  attr :status, :atom, required: true
  attr :target, :atom, required: true
  attr :href, :string, required: true
  attr :label, :string, required: true

  defp total_segment(assigns) do
    ~H"""
    <span :if={@status == @target} class="text-zinc-900">{@label}</span>
    <.link :if={@status != @target} patch={@href} class="text-zinc-500 underline">{@label}</.link>
    """
  end

  def handle_event("resolve", %{"error_id" => error_id}, socket) do
    socket =
      with {:ok, error} <- Errors.resolve(socket.assigns.project.id, error_id, :resolved) do
        %{project: project, current_user: current_user} = socket.assigns
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

  def handle_event("unresolve", %{"error_id" => error_id}, socket) do
    socket =
      with {:ok, error} <- Errors.resolve(socket.assigns.project.id, error_id, :unresolved) do
        %{project: project, current_user: current_user} = socket.assigns
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

  def handle_info({:refresh, error_id}, socket) do
    socket = assign_counts(socket)

    case Errors.get(error_id) do
      nil -> {:noreply, stream_delete_by_dom_id(socket, :errors, "errors-#{error_id}")}
      error -> {:noreply, stream_insert(socket, :errors, error)}
    end
  end

  def handle_info({:add, error_id}, socket) do
    socket = assign_counts(socket)

    case Errors.get(error_id) do
      nil ->
        {:noreply, stream_delete_by_dom_id(socket, :errors, "errors-#{error_id}")}

      error ->
        # Delete first so a recurring error that is already listed moves to the top.
        socket = stream_delete(socket, :errors, error)

        socket =
          if matches?(error, socket.assigns.status),
            do: stream_insert(socket, :errors, error, at: 0),
            else: socket

        {:noreply, socket}
    end
  end

  defp parse_status("resolved"), do: :resolved
  defp parse_status("all"), do: :all
  defp parse_status(_), do: :unresolved

  defp matches?(_error, :all), do: true
  defp matches?(error, status), do: error.status == status

  defp show_status?(_error, :all), do: true
  defp show_status?(error, status), do: not matches?(error, status)

  defp assign_counts(socket) do
    counts = Errors.status_counts(socket.assigns.project.id)
    assign(socket, :counts, Map.put(counts, :total, counts.unresolved + counts.resolved))
  end

  defp empty?(:all, counts), do: counts.total == 0
  defp empty?(status, counts), do: counts[status] == 0

  defp empty_text(:unresolved, %{total: t}) when t > 0, do: "No unresolved errors."
  defp empty_text(:resolved, %{total: t}) when t > 0, do: "No resolved errors."
  defp empty_text(_, _), do: "No errors yet."

  defp pluralize(1, word), do: "1 #{word}"
  defp pluralize(n, word), do: "#{n} #{word}s"
end
