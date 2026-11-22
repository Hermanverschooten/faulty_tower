defmodule FaultyTowerWeb.ProjectLive.Edit do
  alias FaultyTower.Project
  alias FaultyTower.Organization
  use FaultyTowerWeb, :live_view
  alias FaultyTower.Repo

  def mount(%{"project" => id}, __session, socket) do
    socket =
      with {:ok, project} <- Project.fetch(id, :organization),
           true <- Project.editable_by?(project, socket.assigns.current_user) do
        form =
          as_form(project, %{})

        organizations =
          Organization.list()
          |> Enum.map(&{&1.name, &1.id})

        key_url = url(~p"/api/report/#{project.key}")

        socket
        |> assign(:project, project)
        |> assign(:key_url, key_url)
        |> assign(:form, form)
        |> assign(:organizations, organizations)
        |> assign(:deleting, false)
      else
        _ ->
          socket
          |> put_flash(:error, "Project not found")
          |> push_navigate(to: ~p"/")
      end

    ok(socket)
  end

  def render(assigns) do
    ~H"""
    <div class="text-sm text-zinc-500">
      <.link navigate={~p"/project/#{@project.key}"} class="hover:text-zinc-900 hover:underline">
        {@project.organization.name} / {@project.name}
      </.link>
    </div>
    <h1 class="mt-1 mb-6 text-2xl font-semibold text-balance">Edit project</h1>
    <.sheet>
      <.simple_form
        for={@form}
        id="edit-project-form"
        phx-change="validate"
        phx-submit="save"
      >
        <h2 class="text-sm font-medium text-zinc-500">Project</h2>
        <.input type="text" field={@form[:name]} label="Project name" required data-1p-ignore />
        <div>
          <.input
            type="text"
            field={@form[:otp_app]}
            label="OTP application name"
            required
            data-1p-ignore
          />
          <p class="mt-1 text-sm text-zinc-500">
            Frames from this application are shown as app frames; others are dimmed.
          </p>
        </div>
        <.input
          :if={@current_user.admin}
          type="select"
          options={@organizations}
          label="Organization"
          field={@form[:organization_id]}
        />
        <div :if={!@current_user.admin}>
          <.label>Organization</.label>
          <p class="mt-1 text-sm text-zinc-900">{@project.organization.name}</p>
        </div>

        <div class="space-y-5 border-t border-gray-200 pt-5">
          <h2 class="text-sm font-medium text-zinc-500">Reporting</h2>
          <div>
            <.label for="key_url">Project key</.label>
            <div class="relative mt-1">
              <input
                type="text"
                id="key_url"
                value={@key_url}
                class="block w-full rounded-md border border-zinc-300 bg-white pr-10 text-sm text-zinc-900 shadow-none focus:border-zinc-500 focus:ring-0 focus:outline-none"
                readonly
              />
              <button
                type="button"
                title="Copy"
                phx-click={JS.dispatch("phx:copy", to: "#key_url")}
                class="absolute inset-y-0 right-0 flex items-center pr-3 text-zinc-500 hover:text-zinc-900"
              >
                <.icon name="hero-document-duplicate" class="w-4 h-4" />
              </button>
            </div>
          </div>
          <div>
            <.label for="project_ntfy">NTFY Topic</.label>
            <div class="mt-1 flex items-center rounded-md border border-zinc-300 bg-white pl-3 focus-within:border-zinc-500">
              <div class="shrink-0 select-none pr-1 text-sm text-zinc-500">faulty-</div>
              <input
                type="text"
                name={@form[:ntfy].name}
                id="project_ntfy"
                class="block min-w-0 grow rounded-r-md border-0 bg-transparent px-0 text-sm text-zinc-900 focus:ring-0 focus:outline-none"
                value={Phoenix.HTML.Form.normalize_value("text", @form[:ntfy].value)}
              />
            </div>
          </div>
        </div>

        <div class="space-y-5 border-t border-gray-200 pt-5">
          <h2 class="text-sm font-medium text-zinc-500">Repository</h2>
          <.input
            type="select"
            options={[{"None", ""}, {"GitHub", "github"}, {"Forgejo", "forgejo"}]}
            label="Git provider"
            field={@form[:git_provider]}
          />
          <.inputs_for :let={repo} field={@form[:repository]}>
            <.input
              type="text"
              field={repo[:repo]}
              label="Repository"
              placeholder="organization/repo"
            />
            <div>
              <.input type="text" field={repo[:issue_repo]} label="Issues repository" />
              <p class="mt-1 text-sm text-zinc-500">
                Leave empty if issues live in the same repository.
              </p>
            </div>
            <.input type="text" field={repo[:branch]} label="Branch" placeholder="main" />
          </.inputs_for>
        </div>

        <div class="flex items-center gap-4 border-t border-gray-200 pt-5">
          <.button type="submit">Update project</.button>
          <.link
            navigate={~p"/project/#{@project.key}"}
            class="text-sm text-zinc-500 hover:text-zinc-900"
          >
            Cancel
          </.link>
        </div>
      </.simple_form>

      <div class="mt-8 border-t border-gray-200 pt-6">
        <p class="text-sm text-zinc-500">Deleting a project also removes all its logged errors.</p>
        <button
          type="button"
          phx-click="delete"
          class="mt-2 text-sm text-red-700 underline decoration-red-200 underline-offset-4 hover:text-red-900"
        >
          Delete project
        </button>
      </div>
    </.sheet>
    <.modal :if={@deleting} id="confirm-delete" show on_cancel={JS.push("cancel-delete")}>
      <div class="text-center">
        <div class="mb-4">
          Are you sure you want to delete the project?
          <div class="font-semibold">{@project.name}</div>
          This will also remove all logged errors!
        </div>
        <div class="flex justify-around">
          <.button phx-click="confirm-delete" variant="danger" class="w-32">
            Yes
          </.button>
          <.button phx-click="cancel-delete" class="w-32">No</.button>
        </div>
      </div>
    </.modal>
    """
  end

  def handle_event("validate", %{"project" => project_params}, socket) do
    form =
      as_form(socket.assigns.project, project_params)

    socket
    |> assign(:form, form)
    |> noreply()
  end

  def handle_event("save", %{"project" => params}, socket) do
    params =
      if socket.assigns.current_user.admin,
        do: params,
        else: Map.delete(params, "organization_id")

    with {:ok, project} <-
           Project.update(socket.assigns.project, params) do
      project = Repo.preload(project, :organization, force: true)
      Phoenix.PubSub.broadcast(FaultyTower.PubSub, "project:#{project.key}", {:refresh, 0})

      socket
      |> assign(project: project)
      |> put_flash(:info, "Project updated")
    else
      {:error, changeset} ->
        form = to_form(changeset)

        socket
        |> put_flash(:error, "Failed to update project")
        |> assign(:form, form)
    end
    |> noreply()
  end

  def handle_event("delete", _params, socket) do
    socket
    |> assign(:deleting, true)
    |> noreply()
  end

  def handle_event("cancel-delete", _params, socket) do
    socket
    |> assign(:deleting, false)
    |> noreply()
  end

  def handle_event("confirm-delete", _params, socket) do
    case Project.delete(socket.assigns.project) do
      {:ok, _} ->
        socket
        |> put_flash(:success, "Project has been deleted!")
        |> push_navigate(to: ~p"/organizations")

      {:error, changeset} ->
        socket
        |> put_flash(:error, "Failed to delete project: #{inspect(changeset)}")
        |> assign(:deleting, false)
    end
    |> noreply()
  end

  defp as_form(project, attrs) do
    Project.changeset(project, attrs)
    |> to_form()
  end
end
