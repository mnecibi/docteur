defmodule DocteurWeb.ClientForgotPasswordLiveTest do
  use DocteurWeb.ConnCase

  import Phoenix.LiveViewTest
  import Docteur.ProfileFixtures

  alias Docteur.Profile
  alias Docteur.Repo

  describe "Forgot password page" do
    test "renders email page", %{conn: conn} do
      {:ok, lv, html} = live(conn, ~p"/clients/reset_password")

      assert html =~ "Forgot your password?"
      assert has_element?(lv, ~s|a[href="#{~p"/clients/register"}"]|, "Register")
      assert has_element?(lv, ~s|a[href="#{~p"/clients/log_in"}"]|, "Log in")
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_client(client_fixture())
        |> live(~p"/clients/reset_password")
        |> follow_redirect(conn, ~p"/")

      assert {:ok, _conn} = result
    end
  end

  describe "Reset link" do
    setup do
      %{client: client_fixture()}
    end

    test "sends a new reset password token", %{conn: conn, client: client} do
      {:ok, lv, _html} = live(conn, ~p"/clients/reset_password")

      {:ok, conn} =
        lv
        |> form("#reset_password_form", client: %{"email" => client.email})
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "If your email is in our system"

      assert Repo.get_by!(Profile.ClientToken, client_id: client.id).context ==
               "reset_password"
    end

    test "does not send reset password token if email is invalid", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/clients/reset_password")

      {:ok, conn} =
        lv
        |> form("#reset_password_form", client: %{"email" => "unknown@example.com"})
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "If your email is in our system"
      assert Repo.all(Profile.ClientToken) == []
    end
  end
end
