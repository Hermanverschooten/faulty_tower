defmodule FaultyTowerWeb.UserLive do
  use FaultyTowerWeb, :live_view
  alias FaultyTower.Organization
  alias FaultyTower.User

  on_mount {FaultyTowerWeb.UserAuth, :ensure_admin}

  @impl true
  def mount(_, _session, socket) do
    users = User.list()
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
    <h1 class="text-2xl font-semibold flex items-center">
      Users
      <button type="button" phx-click="add">
        <.icon name="hero-user-plus" class="ml-2 w-5 h-5" />
      </button>
    </h1>
    <ul>
      <li
        :for={user <- @users}
        class="hover:underline cursor-pointer"
        phx-click="edit"
        phx-value-id={user.id}
      >
        {user.email}
      </li>
    </ul>
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

        <div>
          <.button type="submit">Save</.button>
          <.button type="button" phx-click={JS.exec("data-cancel", to: "#user_edit")}>Cancel</.button>
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
          "organizations" => []
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
      with {:ok, _user} <- insert_or_update(socket.assigns.user, params) do
        users = User.list()

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
