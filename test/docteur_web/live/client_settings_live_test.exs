defmodule DocteurWeb.ClientSettingsLiveTest do
  use DocteurWeb.ConnCase

  alias Docteur.Profile
  import Phoenix.LiveViewTest
  import Docteur.ProfileFixtures

  describe "Settings page" do
    test "renders settings page", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_client(client_fixture())
        |> live(~p"/clients/settings")

      assert html =~ "Change Email"
      assert html =~ "Change Password"
    end

    test "redirects if client is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/clients/settings")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/clients/log_in"
      assert %{"error" => "You must log in to access this page."} = flash
    end
  end

  describe "update email form" do
    setup %{conn: conn} do
      password = valid_client_password()
      client = client_fixture(%{password: password})
      %{conn: log_in_client(conn, client), client: client, password: password}
    end

    test "updates the client email", %{conn: conn, password: password, client: client} do
      new_email = unique_client_email()

      {:ok, lv, _html} = live(conn, ~p"/clients/settings")

      result =
        lv
        |> form("#email_form", %{
          "current_password" => password,
          "client" => %{"email" => new_email}
        })
        |> render_submit()

      assert result =~ "A link to confirm your email"
      assert Profile.get_client_by_email(client.email)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/clients/settings")

      result =
        lv
        |> element("#email_form")
        |> render_change(%{
          "action" => "update_email",
          "current_password" => "invalid",
          "client" => %{"email" => "with spaces"}
        })

      assert result =~ "Change Email"
      assert result =~ "must have the @ sign and no spaces"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn, client: client} do
      {:ok, lv, _html} = live(conn, ~p"/clients/settings")

      result =
        lv
        |> form("#email_form", %{
          "current_password" => "invalid",
          "client" => %{"email" => client.email}
        })
        |> render_submit()

      assert result =~ "Change Email"
      assert result =~ "did not change"
      assert result =~ "is not valid"
    end
  end

  describe "update password form" do
    setup %{conn: conn} do
      password = valid_client_password()
      client = client_fixture(%{password: password})
      %{conn: log_in_client(conn, client), client: client, password: password}
    end

    test "updates the client password", %{conn: conn, client: client, password: password} do
      new_password = valid_client_password()

      {:ok, lv, _html} = live(conn, ~p"/clients/settings")

      form =
        form(lv, "#password_form", %{
          "current_password" => password,
          "client" => %{
            "email" => client.email,
            "password" => new_password,
            "password_confirmation" => new_password
          }
        })

      render_submit(form)

      new_password_conn = follow_trigger_action(form, conn)

      assert redirected_to(new_password_conn) == ~p"/clients/settings"

      assert get_session(new_password_conn, :client_token) != get_session(conn, :client_token)

      assert Phoenix.Flash.get(new_password_conn.assigns.flash, :info) =~
               "Password updated successfully"

      assert Profile.get_client_by_email_and_password(client.email, new_password)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/clients/settings")

      result =
        lv
        |> element("#password_form")
        |> render_change(%{
          "current_password" => "invalid",
          "client" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })

      assert result =~ "Change Password"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/clients/settings")

      result =
        lv
        |> form("#password_form", %{
          "current_password" => "invalid",
          "client" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })
        |> render_submit()

      assert result =~ "Change Password"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
      assert result =~ "is not valid"
    end
  end

  describe "confirm email" do
    setup %{conn: conn} do
      client = client_fixture()
      email = unique_client_email()

      token =
        extract_client_token(fn url ->
          Profile.deliver_client_update_email_instructions(%{client | email: email}, client.email, url)
        end)

      %{conn: log_in_client(conn, client), token: token, email: email, client: client}
    end

    test "updates the client email once", %{conn: conn, client: client, token: token, email: email} do
      {:error, redirect} = live(conn, ~p"/clients/settings/confirm_email/#{token}")

      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/clients/settings"
      assert %{"info" => message} = flash
      assert message == "Email changed successfully."
      refute Profile.get_client_by_email(client.email)
      assert Profile.get_client_by_email(email)

      # use confirm token again
      {:error, redirect} = live(conn, ~p"/clients/settings/confirm_email/#{token}")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/clients/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
    end

    test "does not update email with invalid token", %{conn: conn, client: client} do
      {:error, redirect} = live(conn, ~p"/clients/settings/confirm_email/oops")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/clients/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
      assert Profile.get_client_by_email(client.email)
    end

    test "redirects if client is not logged in", %{token: token} do
      conn = build_conn()
      {:error, redirect} = live(conn, ~p"/clients/settings/confirm_email/#{token}")
      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/clients/log_in"
      assert %{"error" => message} = flash
      assert message == "You must log in to access this page."
    end
  end
end
