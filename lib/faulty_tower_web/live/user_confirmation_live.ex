defmodule FaultyTowerWeb.UserConfirmationLive do
  use FaultyTowerWeb, :live_view

  alias FaultyTower.Authentication

  def render(%{live_action: :edit} = assigns) do
    ~H"""
    <.sheet centered class="mt-10">
      <h1 class="text-lg font-semibold leading-tight text-balance text-zinc-900">Confirm Account</h1>

      <.simple_form for={@form} id="confirmation_form" phx-submit="confirm_account" class="mt-6">
        <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
        <:actions>
          <.button phx-disable-with="Confirming..." class="w-full">Confirm my account</.button>
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

  def mount(%{"token" => token}, _session, socket) do
    cond do
      Authentication.get_user_by_confirmation_token(token) ->
        form = to_form(%{"token" => token}, as: "user")
        {:ok, assign(socket, form: form), temporary_assigns: [form: nil]}

      # A used link revisited by a confirmed user: no warning, as on submit.
      match?(%{confirmed_at: %DateTime{}}, socket.assigns[:current_user]) ->
        {:ok, redirect(socket, to: ~p"/")}

      true ->
        {:ok,
         socket
         |> put_flash(:error, "User confirmation link is invalid or it has expired.")
         |> redirect(to: ~p"/users/log_in")}
    end
  end

  # Do not log in the user after confirmation to avoid a
  # leaked token giving the user access to the account.
  def handle_event("confirm_account", %{"user" => %{"token" => token}}, socket) do
    case Authentication.confirm_user(token) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "User confirmed successfully.")
         |> redirect(to: ~p"/")}

      :error ->
        # If there is a current user and the account was already confirmed,
        # then odds are that the confirmation link was already visited, either
        # by some automation or by the user themselves, so we redirect without
        # a warning message.
        case socket.assigns do
          %{current_user: %{confirmed_at: confirmed_at}} when not is_nil(confirmed_at) ->
            {:noreply, redirect(socket, to: ~p"/")}

          %{} ->
            {:noreply,
             socket
             |> put_flash(:error, "User confirmation link is invalid or it has expired.")
             |> redirect(to: ~p"/users/log_in")}
        end
    end
  end
end
