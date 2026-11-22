defmodule FaultyTowerWeb.UserConfirmationLiveTest do
  use FaultyTowerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import FaultyTower.AuthenticationFixtures

  alias FaultyTower.Authentication

  setup do
    user = user_fixture()

    token =
      extract_user_token(fn url ->
        Authentication.deliver_user_confirmation_instructions(user, url)
      end)

    %{user: user, token: token}
  end

  describe "Confirm page" do
    test "renders the confirm form for a valid token", %{conn: conn, token: token} do
      {:ok, lv, _html} = live(conn, ~p"/users/confirm/#{token}")

      assert has_element?(lv, "#confirmation_form button", "Confirm my account")
    end

    test "redirects to log in with an error for an invalid token", %{conn: conn} do
      assert {:error, {:redirect, to}} = live(conn, ~p"/users/confirm/invalid")

      assert to == %{
               flash: %{"error" => "User confirmation link is invalid or it has expired."},
               to: ~p"/users/log_in"
             }
    end

    test "redirects home without a warning when a confirmed user revisits a used link",
         %{conn: conn, user: user, token: token} do
      {:ok, _} = Authentication.confirm_user(token)
      user = Authentication.get_user!(user.id)

      assert {:error, {:redirect, %{to: "/", flash: %{}}}} =
               conn |> log_in_user(user) |> live(~p"/users/confirm/#{token}")
    end

    test "confirms the account", %{conn: conn, user: user, token: token} do
      {:ok, lv, _html} = live(conn, ~p"/users/confirm/#{token}")

      {:ok, conn} =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "User confirmed successfully"
      assert Authentication.get_user!(user.id).confirmed_at
    end
  end

  describe "Email label" do
    test "forgot password and confirmation instructions label the email field", %{conn: conn} do
      for path <- [~p"/users/reset_password", ~p"/users/confirm"] do
        {:ok, lv, _html} = live(conn, path)
        assert has_element?(lv, "label", "Email"), "no Email label on #{path}"
      end
    end
  end
end
