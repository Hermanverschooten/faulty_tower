defmodule FaultyTower.Authentication.UserNotifier do
  import Swoosh.Email

  alias FaultyTower.Authentication.UserToken
  alias FaultyTower.Mailer

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"FaultyTower", "info@faultytower.com"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(user, url) do
    days = UserToken.confirm_validity_in_days()

    deliver(user.email, "Confirmation instructions", """

    ==============================

    Hi #{user.email},

    You can confirm your account by visiting the URL below:

    #{url}

    This link is valid for #{days} days.

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to reset a user password.
  """
  def deliver_reset_password_instructions(user, url) do
    days = UserToken.reset_password_validity_in_days()

    deliver(user.email, "Reset password instructions", """

    ==============================

    Hi #{user.email},

    You can reset your password by visiting the URL below:

    #{url}

    This link is valid for #{days} day.

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    days = UserToken.change_email_validity_in_days()

    deliver(user.email, "Update email instructions", """

    ==============================

    Hi #{user.email},

    You can change your email by visiting the URL below:

    #{url}

    This link is valid for #{days} days.

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver welcome instructions to a new user.
  """
  def deliver_welcome_instructions(user, url) do
    deliver(user.email, "Welcome to FaultyTower", """

    ==============================

    Hi #{user.email},

    An account has been created for you on FaultyTower.

    You can set your password by visiting the URL below:

    #{url}

    ==============================
    """)
  end
end
