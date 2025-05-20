defmodule FaultyTowerWeb.OrganizationLive do
  use FaultyTowerWeb, :live_view
  alias FaultyTower.Organization

  on_mount {FaultyTowerWeb.UserAuth, :ensure_admin}

  @impl true
  def mount(_params, _session, socket) do
    organizations = Organization.list(:projects)

    {:ok,
     socket
     |> assign(:organizations, organizations)
     |> assign(:form, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h1 class="text-2xl font-semibold flex items-center">
      Organizations
      <button type="button" phx-click="add">
        <.icon name="hero-plus" class="ml-2 w-5 h-5" />
      </button>
    </h1>
    <ul class="mt-8">
      <li :for={organization <- @organizations} class="my-2">
        <button
          type="button"
          class="hover:underline font-semibold"
          phx-click="edit"
          phx-value-id={organization.id}
        >
          {organization.name}
        </button>
        <.link navigate={~p"/project/#{organization.id}/new"} title="Add project">
          <.icon name="hero-squares-plus" class="w-4 h-4" />
        </.link>
        <ul class="ml-4">
          <li :for={project <- organization.projects}>
            <.link navigate={~p"/project/#{project.id}/edit"} class="hover:underline">
              {project.name}
            </.link>
          </li>
        </ul>
      </li>
    </ul>
    <.modal :if={@form} id="organization_edit" show on_cancel={JS.push("cancel")}>
      <.simple_form
        for={@form}
        id="organization_edit_form"
        phx-change="validate"
        phx-submit="save"
        phx-remove={hide_modal("organization_edit")}
      >
        <.input type="text" field={@form[:name]} label="Name" data-1p-ignore />

        <div>
          <.button type="submit">Save</.button>
          <.button type="button" phx-click={JS.exec("data-cancel", to: "#organization_edit")}>
            Cancel
          </.button>
        </div>
      </.simple_form>
    </.modal>
    """
  end

  @impl true
  def handle_event("add", _params, socket) do
    organization = %Schema.Organization{}

    form =
      to_form(
        %{
          "name" => ""
        },
        as: :organization
      )

    org_list = Enum.map(socket.assigns.organizations, &{&1.name, &1.id})

    {:noreply,
     socket
     |> assign(form: form)
     |> assign(org_list: org_list)
     |> assign(organization: organization)}
  end

  def handle_event("edit", %{"id" => organization_id}, socket) do
    socket =
      with {:ok, organization} <- Organization.fetch(organization_id) do
        form =
          to_form(
            %{
              "name" => organization.name
            },
            as: :organization
          )

        socket
        |> assign(form: form)
        |> assign(organization: organization)
      else
        {:error, :not_found} ->
          socket
          |> put_flash(:error, "organization not found")
      end

    {:noreply, socket}
  end

  def handle_event("cancel", _params, socket) do
    {:noreply, socket |> assign(form: nil)}
  end

  def handle_event("validate", %{"organization" => organization}, socket) do
    form = to_form(organization, as: :organization)
    {:noreply, socket |> assign(form: form)}
  end

  def handle_event("save", %{"organization" => params}, socket) do
    socket =
      with {:ok, _organization} <- insert_or_update(socket.assigns.organization, params) do
        organizations = Organization.list()

        socket
        |> assign(form: nil)
        |> assign(organizations: organizations)
      else
        {:error, changeset} ->
          form = to_form(changeset, as: :organization)

          socket
          |> assign(form: form)
      end

    {:noreply, socket}
  end

  defp insert_or_update(%Schema.Organization{id: nil}, params),
    do: Organization.insert(params)

  defp insert_or_update(organization, params), do: Organization.update(organization, params)
end
