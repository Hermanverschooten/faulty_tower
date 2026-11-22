defmodule FaultyTowerWeb.OrganizationLive.Edit do
  use FaultyTowerWeb, :live_view

  alias FaultyTower.Organization

  on_mount {FaultyTowerWeb.UserAuth, :ensure_admin}

  @impl true
  def mount(_params, _session, socket) do
    global_forgejo = Application.get_env(:faulty_tower, :forgejo)

    {:ok,
     socket
     |> assign(:global_forgejo_configured, global_forgejo != nil)
     |> assign(:global_forgejo_url, global_forgejo[:instance_url])}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    organization = %Schema.Organization{}
    changeset = Organization.changeset(organization, %{})
    form = to_form(changeset, as: :organization)

    socket
    |> assign(:page_title, "New Organization")
    |> assign(:organization, organization)
    |> assign(:form, form)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    case Organization.fetch(id) do
      {:ok, organization} ->
        changeset = Organization.changeset(organization, %{})
        form = to_form(changeset, as: :organization)

        socket
        |> assign(:page_title, "Edit #{organization.name}")
        |> assign(:organization, organization)
        |> assign(:form, form)

      {:error, :not_found} ->
        socket
        |> put_flash(:error, "Organization not found")
        |> push_navigate(to: ~p"/organizations")
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="text-sm text-zinc-500">
      <.link navigate={~p"/organizations"} class="hover:text-zinc-900 hover:underline">
        Organizations
      </.link>
    </div>
    <h1 class="mt-1 mb-6 text-2xl font-semibold text-balance">
      {if @live_action == :new, do: "New organization", else: "Edit organization"}
    </h1>
    <.sheet>
      <.simple_form for={@form} id="organization_edit_form" phx-change="validate" phx-submit="save">
        <.input type="text" field={@form[:name]} label="Name" data-1p-ignore />

        <div class="space-y-5 border-t border-gray-200 pt-5">
          <h2 class="text-sm font-medium text-zinc-500">Forgejo</h2>
          <p :if={@global_forgejo_configured} class="text-sm text-zinc-500">
            Global Forgejo settings apply when these are blank.
          </p>
          <.inputs_for :let={f} field={@form[:forgejo]}>
            <div>
              <.input
                type="text"
                field={f[:instance_url]}
                label="Instance URL"
                placeholder={@global_forgejo_url || "https://git.example.com"}
              />
              <p class="mt-1 text-sm text-zinc-500">Base URL of your Forgejo instance.</p>
            </div>
            <div>
              <.input
                type="password"
                field={f[:access_token]}
                label="Access token"
                placeholder="Personal access token"
                autocomplete="off"
              />
              <p class="mt-1 text-sm text-zinc-500">
                Settings &gt; Applications &gt; Generate New Token, scope <code class="font-mono">write:issue</code>.
              </p>
            </div>
            <div>
              <.input
                type="password"
                field={f[:webhook_secret]}
                label="Webhook secret"
                placeholder="Secret for webhook signature verification"
                autocomplete="off"
              />
              <p class="mt-1 text-sm text-zinc-500">Used to verify webhook signatures.</p>
            </div>
          </.inputs_for>
          <details class="text-sm text-zinc-500" phx-mounted={JS.ignore_attributes(["open"])}>
            <summary class="cursor-pointer hover:text-zinc-900">How to add the webhook</summary>
            <div class="mt-2 space-y-2">
              <p>
                In your Forgejo organization settings go to Webhooks, Add Webhook, and choose Forgejo (or Gitea).
              </p>
              <ul class="list-disc pl-5 space-y-1">
                <li>
                  Target URL:
                  <code class="font-mono break-all">
                    {FaultyTowerWeb.Endpoint.url()}/api/forgejo/webhook
                  </code>
                </li>
                <li>HTTP method: POST</li>
                <li>Secret: the same secret as above</li>
                <li>Trigger on: Custom Events, Issues only</li>
                <li>Branch filter: keep the default (<code class="font-mono">*</code>)</li>
                <li>Authorization header: leave empty</li>
              </ul>
              <p>A webhook at organization level covers all repositories in the organization.</p>
            </div>
          </details>
        </div>

        <div class="flex items-center gap-4 pt-1">
          <.button type="submit">Save</.button>
          <.link navigate={~p"/organizations"} class="text-sm text-zinc-500 hover:text-zinc-900">
            Cancel
          </.link>
        </div>
      </.simple_form>
    </.sheet>
    """
  end

  @impl true
  def handle_event("validate", %{"organization" => params}, socket) do
    changeset =
      socket.assigns.organization
      |> Organization.changeset(params)
      |> Map.put(:action, :validate)

    form = to_form(changeset, as: :organization)
    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"organization" => params}, socket) do
    case insert_or_update(socket.assigns.organization, params) do
      {:ok, _organization} ->
        {:noreply,
         socket
         |> put_flash(:info, "Organization saved successfully")
         |> push_navigate(to: ~p"/organizations")}

      {:error, changeset} ->
        form = to_form(changeset, as: :organization)
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp insert_or_update(%Schema.Organization{id: nil}, params),
    do: Organization.insert(params)

  defp insert_or_update(organization, params),
    do: Organization.update(organization, params)
end
