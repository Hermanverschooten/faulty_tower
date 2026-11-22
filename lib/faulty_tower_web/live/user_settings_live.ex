defmodule FaultyTowerWeb.UserSettingsLive do
  use FaultyTowerWeb, :live_view

  alias FaultyTower.Authentication

  def render(assigns) do
    ~H"""
    <h1 class="mt-1 text-2xl font-semibold text-balance">Account settings</h1>
    <div class="mb-6 text-sm text-zinc-500">{@current_email}</div>
    <.sheet>
      <.simple_form
        for={@email_form}
        id="email_form"
        phx-submit="update_email"
        phx-change="validate_email"
      >
        <h2 class="text-sm font-medium text-zinc-500">Email</h2>
        <.input field={@email_form[:email]} type="email" label="Email" required />
        <.input
          field={@email_form[:current_password]}
          name="current_password"
          id="current_password_for_email"
          type="password"
          label="Current password"
          value={@email_form_current_password}
          required
        />
        <:actions>
          <.button phx-disable-with="Changing...">Change Email</.button>
        </:actions>
      </.simple_form>

      <div class="mt-8 border-t border-gray-200 pt-6">
        <.simple_form
          for={@password_form}
          id="password_form"
          action={~p"/users/log_in?_action=password_updated"}
          method="post"
          phx-change="validate_password"
          phx-submit="update_password"
          phx-trigger-action={@trigger_submit}
        >
          <h2 class="text-sm font-medium text-zinc-500">Password</h2>
          <input
            name={@password_form[:email].name}
            type="hidden"
            id="hidden_user_email"
            value={@current_email}
          />
          <.input field={@password_form[:password]} type="password" label="New password" required />
          <.input
            field={@password_form[:password_confirmation]}
            type="password"
            label="Confirm new password"
          />
          <.input
            field={@password_form[:current_password]}
            name="current_password"
            type="password"
            label="Current password"
            id="current_password_for_password"
            value={@current_password}
            required
          />
          <:actions>
            <.button phx-disable-with="Changing...">Change Password</.button>
          </:actions>
        </.simple_form>
      </div>

      <div class="mt-8 border-t border-gray-200 pt-6">
        <h2 class="text-sm font-medium text-zinc-500">MCP token</h2>
        <p class="mt-1 text-sm text-zinc-500">
          Use this token to authenticate with the FaultyTower MCP server for AI assistants.
        </p>
        <div class="mt-3 flex items-end gap-4">
          <div class="min-w-0 flex-1">
            <.label for="mcp-token-input">Token</.label>
            <input
              id="mcp-token-input"
              type="text"
              value={@mcp_token}
              readonly
              class={[input_class(), "font-mono"]}
            />
          </div>
          <button
            type="button"
            phx-click={
              JS.dispatch("phx:copy", to: "#mcp-token-input")
              |> JS.dispatch("phx:copied", to: "#mcp-token-input")
            }
            class="shrink-0 pb-2 text-sm text-zinc-500 underline decoration-zinc-300 underline-offset-4 hover:text-zinc-900"
          >
            Copy
          </button>
          <button
            type="button"
            phx-click="regenerate_token"
            data-confirm="Are you sure? Your existing MCP integrations will need to be reconfigured with the new token."
            class="shrink-0 pb-2 text-sm text-zinc-500 underline decoration-zinc-300 underline-offset-4 hover:text-zinc-900"
          >
            Regenerate
          </button>
        </div>
        <p class="mt-2 text-sm text-zinc-500">
          Keep this token secure. It provides full access to your FaultyTower account via the MCP API. This token does not expire.
        </p>
      </div>
    </.sheet>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Authentication.update_user_email(socket.assigns.current_user, token) do
        :ok ->
          put_flash(socket, :info, "Email changed successfully.")

        :error ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    email_changeset = Authentication.change_user_email(user)
    password_changeset = Authentication.change_user_password(user)

    socket =
      socket
      |> assign(:current_password, nil)
      |> assign(:email_form_current_password, nil)
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)
      |> assign(:mcp_token, user.mcp_token)

    {:ok, socket}
  end

  def handle_event("validate_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    email_form =
      socket.assigns.current_user
      |> Authentication.change_user_email(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form, email_form_current_password: password)}
  end

  def handle_event("update_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Authentication.apply_user_email(user, password, user_params) do
      {:ok, applied_user} ->
        Authentication.deliver_user_update_email_instructions(
          applied_user,
          user.email,
          &url(~p"/users/settings/confirm_email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info) |> assign(email_form_current_password: nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :email_form, to_form(Map.put(changeset, :action, :insert)))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    password_form =
      socket.assigns.current_user
      |> Authentication.change_user_password(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form, current_password: password)}
  end

  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Authentication.update_user_password(user, password, user_params) do
      {:ok, user} ->
        password_form =
          user
          |> Authentication.change_user_password(user_params)
          |> to_form()

        {:noreply, assign(socket, trigger_submit: true, password_form: password_form)}

      {:error, changeset} ->
        {:noreply, assign(socket, password_form: to_form(changeset))}
    end
  end

  def handle_event("regenerate_token", _params, socket) do
    user = socket.assigns.current_user
    updated_user = Authentication.regenerate_mcp_token(user)

    socket =
      socket
      |> assign(:mcp_token, updated_user.mcp_token)
      |> put_flash(:info, "MCP token regenerated successfully.")

    {:noreply, socket}
  end
end
