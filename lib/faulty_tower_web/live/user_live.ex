defmodule FaultyTowerWeb.UserLive do
  use FaultyTowerWeb, :live_view
  alias FaultyTower.Authentication
  alias FaultyTower.Organization
  alias FaultyTower.User

  on_mount {FaultyTowerWeb.UserAuth, :ensure_admin}

  @impl true
  def mount(_, _session, socket) do
    users = User.list(:organizations)
    organizations = Organization.list()

    {:ok,
     socket
     |> assign(users: users)
     |> assign(organizations: organizations)
     |> assign(form: nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex items-baseline gap-4">
      <h1 class="text-2xl font-semibold [text-wrap:balance]">Users</h1>
      <button
        type="button"
        phx-click="add"
        class="text-sm text-zinc-500 hover:text-zinc-900"
      >
        Add user
      </button>
    </div>
    <div id="users" class="mt-4 max-sm:border-t border-gray-200 [text-wrap:balance]">
      <div class="max-sm:hidden grid grid-cols-[1fr_1fr_4rem] gap-4 border-b border-gray-200 pb-1 text-xs text-zinc-500">
        <span>Email</span>
        <span>Organizations</span>
        <span>Role</span>
      </div>
      <button
        :for={user <- @users}
        :key={user.id}
        id={"users-#{user.id}"}
        type="button"
        phx-click="edit"
        phx-value-id={user.id}
        class="group block w-full border-b border-gray-200 py-2 text-left sm:grid sm:grid-cols-[1fr_1fr_4rem] sm:gap-4"
      >
        <span class="block text-sm text-zinc-900 group-hover:underline">
          {user.email}
          <span :if={user.name} class="block text-zinc-500">{user.name}</span>
        </span>
        <span class="block text-sm text-zinc-500">
          {Enum.map_join(user.organizations, ", ", & &1.name)}
          <span :if={user.admin} class="sm:hidden">
            {if user.organizations != [], do: "· "}admin
          </span>
        </span>
        <span :if={user.admin} class="max-sm:hidden text-sm text-zinc-500">admin</span>
      </button>
    </div>
    <.modal :if={@form} id="user_edit" show on_cancel={JS.push("cancel")}>
      <.simple_form
        for={@form}
        id="user_edit_form"
        phx-change="validate"
        phx-submit="save"
        phx-remove={hide_modal("user_edit")}
      >
        <.input type="email" field={@form[:email]} label="E-mail" data-1p-ignore />
        <.input type="checkbox" field={@form[:admin]} label="Admin?" />
        <.input
          type="checkgroup"
          options={@org_list}
          field={@form[:organizations]}
          multiple
          checkgroup_empty={false}
          label="Organizations"
        />
        <.input
          :if={@user.id == nil}
          type="checkbox"
          field={@form[:send_welcome_email]}
          label="Send welcome e-mail"
        />

        <div class="flex items-center gap-4 pt-1">
          <.button type="submit">Save</.button>
          <button
            type="button"
            phx-click={JS.push("cancel")}
            class="text-sm text-zinc-500 hover:text-zinc-900"
          >
            Cancel
          </button>
        </div>
      </.simple_form>
    </.modal>
    """
  end

  @impl true
  def handle_event("add", _params, socket) do
    user = %FaultyTower.Authentication.User{}

    form =
      to_form(
        %{
          "email" => "",
          "admin" => "",
          "organizations" => [],
          "send_welcome_email" => true
        },
        as: :user
      )

    org_list = Enum.map(socket.assigns.organizations, &{&1.name, &1.id})

    {:noreply,
     socket
     |> assign(form: form)
     |> assign(org_list: org_list)
     |> assign(user: user)}
  end

  def handle_event("edit", %{"id" => user_id}, socket) do
    socket =
      with {:ok, user} <- User.fetch(user_id, :organizations) do
        form =
          to_form(
            %{
              "email" => user.email,
              "admin" => user.admin,
              "organizations" => user.organizations
            },
            as: :user
          )

        org_list = Enum.map(socket.assigns.organizations, &{&1.name, &1.id})

        socket
        |> assign(form: form)
        |> assign(org_list: org_list)
        |> assign(user: user)
      else
        {:error, :not_found} ->
          socket
          |> put_flash(:error, "User not found")
      end

    {:noreply, socket}
  end

  def handle_event("cancel", _params, socket) do
    {:noreply, socket |> assign(form: nil)}
  end

  def handle_event("validate", %{"user" => user}, socket) do
    form = to_form(user, as: :user)
    {:noreply, socket |> assign(form: form)}
  end

  def handle_event("save", %{"user" => params}, socket) do
    socket =
      with {:ok, user} <- insert_or_update(socket.assigns.user, params) do
        if socket.assigns.user.id == nil and params["send_welcome_email"] == "true" do
          Authentication.deliver_user_welcome_instructions(
            user,
            &url(~p"/users/reset_password/#{&1}")
          )
        end

        users = User.list(:organizations)

        socket
        |> assign(form: nil)
        |> assign(users: users)
      else
        {:error, changeset} ->
          form = to_form(changeset, as: :user)

          socket
          |> assign(form: form)
      end

    {:noreply, socket}
  end

  defp insert_or_update(%FaultyTower.Authentication.User{id: nil}, params),
    do: User.insert(params)

  defp insert_or_update(user, params), do: User.update(user, params)
end
