defmodule FaultyTowerWeb.UserConfirmationInstructionsLive do
  use FaultyTowerWeb, :live_view

  alias FaultyTower.Authentication

  def render(assigns) do
    ~H"""
    <.sheet centered class="mt-10">
      <h1 class="text-lg font-semibold leading-tight text-balance text-zinc-900">
        No confirmation instructions received?
      </h1>
      <p class="mt-1 text-sm text-balance text-zinc-500">
        We'll send a new confirmation link to your inbox
      </p>

      <.simple_form
        for={@form}
        id="resend_confirmation_form"
        phx-submit="send_instructions"
        class="mt-6"
      >
        <.input field={@form[:email]} type="email" label="Email" required />
        <:actions>
          <.button phx-disable-with="Sending..." class="w-full">
            Resend confirmation instructions
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

  def handle_event("send_instructions", %{"user" => %{"email" => email}}, socket) do
    if user = Authentication.get_user_by_email(email) do
      Authentication.deliver_user_confirmation_instructions(
        user,
        &url(~p"/users/confirm/#{&1}")
      )
    end

    info =
      "If your email is in our system and it has not been confirmed yet, you will receive an email with instructions shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> redirect(to: ~p"/")}
  end
end
