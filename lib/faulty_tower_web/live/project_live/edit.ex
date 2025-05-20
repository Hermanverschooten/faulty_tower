defmodule FaultyTowerWeb.ProjectLive.Edit do
  alias FaultyTower.Project
  alias FaultyTower.Organization
  use FaultyTowerWeb, :live_view

  def mount(%{"project" => id}, __session, socket) do
    socket =
      with {:ok, project} <- Project.fetch(id) do
        form =
          as_form(project, %{})

        organizations =
          Organization.list()
          |> Enum.map(&{&1.name, &1.id})

        key_url = url(~p"/api/report/#{project.key}")

        socket
        |> assign(:changed, false)
        |> assign(:project, project)
        |> assign(:key_url, key_url)
        |> assign(:form, form)
        |> assign(:organizations, organizations)
        |> assign(:deleting, false)
      end

    ok(socket)
  end

  def render(assigns) do
    ~H"""
    <h1 class="text-2xl font-semibold">Project {@project.name} - Edit</h1>
    <.simple_form
      for={@form}
      id="edit-project-form"
      phx-change="validate"
      phx-submit="save"
      class="mt-8"
    >
      <.input type="text" field={@form[:name]} label="Project name" required data-1p-ignore />
      <.input
        type="text"
        field={@form[:otp_app]}
        label="OTP application name"
        required
        data-1p-ignore
      />
      <div>
        <.label for="key_url">Project key</.label>
        <div class="relative mt-2">
          <input
            type="text"
            id="key_url"
            value={@key_url}
            class=" block w-full rounded-lg text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6 border-zinc-300 focus:border-zinc-400"
            readonly
          />
          <button
            type="button"
            phx-click={JS.dispatch("phx:copy", to: "#key_url")}
            class="absolute inset-y-0 right-0 flex items-center pr-3"
          >
            <.icon name="hero-document-duplicate" class="w-4 h-4" />
          </button>
        </div>
      </div>
      <.input
        type="select"
        options={@organizations}
        label="Organization"
        field={@form[:organization_id]}
      />
      <div class="border-b border-gray-900/10 pb-12">
        <h2 class="text-base/7 font-semibold text-gray-900">GitHub Repository Information</h2>
      </div>
      <.inputs_for :let={gh} field={@form[:github]}>
        <.input type="text" field={gh[:repo]} label="Repository" placeholder="organization/repo" />
        <.input
          type="text"
          field={gh[:issue_repo]}
          label="Issues repository"
          placeholder="organization/repo - leave empty if the same as above"
        />
        <.input type="text" field={gh[:branch]} label="Branch" placeholder="main" />
      </.inputs_for>
      <div>
        <.label for="project_ntfy">NTFY Topic</.label>
        <div class="mt-2">
          <div class="flex items-center rounded-lg p-0 pl-3 text-zinc-900 focus-ring:0 sm:text-sm sm:leading-6 border-zinc-300 focus-within:border-zinc-400 border bg-gray-100">
            <div class="shrink-0 select-none text-base text-zinc-900 sm:text-sm pr-1">
              faulty-
            </div>
            <input
              type="text"
              name={@form[:ntfy].name}
              id="project_ntfy"
              class="block min-w-0 grow sm:text-sm rounded-r-lg border-0 focus:ring-0 "
              value={Phoenix.HTML.Form.normalize_value("text", @form[:ntfy].value)}
            />
          </div>
        </div>
      </div>
      <div class="flex justify-between">
        <div>
          <.button type="submit">Update project</.button>
          <button onclick="javascript:history.back();" class="ml-4 hover:underline" type="button">
            <span :if={@changed}>Cancel</span><span :if={!@changed}>Return</span>
          </button>
        </div>
        <.button
          phx-click="delete"
          class="bg-red-700 hover:bg-red-400 flex items-center"
          type="button"
        >
          <.icon name="hero-trash" class="w-4 h-4 mr-1" />Delete
        </.button>
      </div>
    </.simple_form>
    <.modal :if={@deleting} id="confirm-delete" show on_cancel={JS.push("cancel-delete")}>
      <div class="text-center">
        <div class="mb-4">
          Are you sure you want to delete the project?
          <div class="font-semibold">{@project.name}</div>
          This will also remove all logged errors!
        </div>
        <div class="flex justify-around">
          <.button phx-click="confirm-delete" class="bg-red-700 hover:bg-red-400 w-32">
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
    |> assign(:changed, true)
    |> assign(:form, form)
    |> noreply()
  end

  def handle_event("save", %{"project" => params}, socket) do
    with {:ok, project} <-
           Project.update(socket.assigns.project, params) do
      Phoenix.PubSub.broadcast(FaultyTower.PubSub, "project:#{project.key}", {:refresh, 0})

      socket
      |> assign(:changed, false)
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
