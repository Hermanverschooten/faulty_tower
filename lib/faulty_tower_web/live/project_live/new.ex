defmodule FaultyTowerWeb.ProjectLive.New do
  alias FaultyTower.Project
  alias FaultyTower.Organization
  use FaultyTowerWeb, :live_view

  def mount(%{"organization_id" => org_id}, __session, socket) do
    socket =
      with {:ok, organization} <- Organization.fetch(org_id) do
        form = as_form(%{organization_id: organization.id})

        socket
        |> assign(:organization, organization)
        |> assign(:form, form)
      end

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <h1 class="text-2xl font-semibold">{@organization.name} - Add new project</h1>
    <.simple_form
      for={@form}
      id="new-project-form"
      phx-change="validate"
      phx-submit="create"
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
      <.button type="submit">Create project</.button>
      <.link navigate={~p"/organizations"} class="ml-4 hover:underline">
        <button type="button">Cancel</button>
      </.link>
    </.simple_form>
    """
  end

  def handle_event("validate", %{"project" => project_params}, socket) do
    form =
      project_params
      |> Map.put("organization_id", 1)
      |> Map.put("key", "demo")
      |> as_form()

    {:noreply, socket |> assign(:form, form)}
  end

  def handle_event("create", %{"project" => params}, socket) do
    socket =
      with {:ok, project} <-
             Project.create(params["name"], socket.assigns.organization.id, params["otp_app"]) do
        socket
        |> put_flash(:info, "Project created")
        |> push_navigate(to: ~p"/project/#{project.id}/edit")
      else
        {:error, changeset} ->
          form = to_form(changeset)

          socket
          |> put_flash(:error, "Failed to create project")
          |> assign(:form, form)
      end

    {:noreply, socket}
  end

  defp as_form(attrs) do
    Project.changeset(%Schema.Project{}, attrs)
    |> to_form()
  end
end
