defmodule FaultyTowerWeb.UserLoginLive do
  use FaultyTowerWeb, :live_view

  def render(assigns) do
    ~H"""
    <.sheet centered class="mt-10">
      <h1 class="text-lg font-semibold leading-tight text-balance text-zinc-900">Log in</h1>

      <.simple_form
        for={@form}
        id="login_form"
        action={~p"/users/log_in"}
        phx-update="ignore"
        class="mt-6"
      >
        <.input field={@form[:email]} type="email" label="Email" required />
        <.input field={@form[:password]} type="password" label="Password" required />

        <:actions>
          <.input field={@form[:remember_me]} type="checkbox" label="Keep me logged in" />
        </:actions>
        <:actions>
          <.button phx-disable-with="Logging in..." class="w-full">Log in</.button>
        </:actions>
        <:actions>
          <.link
            href={~p"/users/reset_password"}
            class="mx-auto text-sm text-zinc-500 hover:text-zinc-900"
          >
            Forgot your password?
          </.link>
        </:actions>
      </.simple_form>
    </.sheet>
    """
  end

  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "user")
    {:ok, assign(socket, form: form), temporary_assigns: [form: form]}
  end
end
