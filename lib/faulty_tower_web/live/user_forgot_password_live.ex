defmodule FaultyTowerWeb.UserForgotPasswordLive do
  use FaultyTowerWeb, :live_view

  alias FaultyTower.Authentication

  def render(assigns) do
    ~H"""
    <.sheet centered class="mt-10">
      <h1 class="text-lg font-semibold leading-tight text-balance text-zinc-900">
        Forgot your password?
      </h1>
      <p class="mt-1 text-sm text-balance text-zinc-500">
        We'll send a password reset link to your inbox
      </p>

      <.simple_form for={@form} id="reset_password_form" phx-submit="send_email" class="mt-6">
        <.input field={@form[:email]} type="email" label="Email" required />
        <:actions>
          <.button phx-disable-with="Sending..." class="w-full">
            Send password reset instructions
          </.button>
        </:actions>
        <:actions>
          <.link href={~p"/users/log_in"} class="mx-auto text-sm text-zinc-500 hover:text-zinc-900">
            Log in
          </.link>
        </:actions>
      </.simple_form>
    </.sheet>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{}, as: "user"))}
  end

  def handle_event("send_email", %{"user" => %{"email" => email}}, socket) do
    if user = Authentication.get_user_by_email(email) do
      Authentication.deliver_user_reset_password_instructions(
        user,
        &url(~p"/users/reset_password/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions to reset your password shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> redirect(to: ~p"/users/log_in")}
  end
end
