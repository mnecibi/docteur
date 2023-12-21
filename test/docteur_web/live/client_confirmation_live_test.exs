defmodule DocteurWeb.ClientConfirmationLiveTest do
  use DocteurWeb.ConnCase

  import Phoenix.LiveViewTest
  import Docteur.ProfileFixtures

  alias Docteur.Profile
  alias Docteur.Repo

  setup do
    %{client: client_fixture()}
  end

  describe "Confirm client" do
    test "renders confirmation page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/clients/confirm/some-token")
      assert html =~ "Confirm Account"
    end

    test "confirms the given token once", %{conn: conn, client: client} do
      token =
        extract_client_token(fn url ->
          Profile.deliver_client_confirmation_instructions(client, url)
        end)

      {:ok, lv, _html} = live(conn, ~p"/clients/confirm/#{token}")

      result =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert {:ok, conn} = result

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "Client confirmed successfully"

      assert Profile.get_client!(client.id).confirmed_at
      refute get_session(conn, :client_token)
      assert Repo.all(Profile.ClientToken) == []

      # when not logged in
      {:ok, lv, _html} = live(conn, ~p"/clients/confirm/#{token}")

      result =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert {:ok, conn} = result

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Client confirmation link is invalid or it has expired"

      # when logged in
      conn =
        build_conn()
        |> log_in_client(client)

      {:ok, lv, _html} = live(conn, ~p"/clients/confirm/#{token}")

      result =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert {:ok, conn} = result
      refute Phoenix.Flash.get(conn.assigns.flash, :error)
    end

    test "does not confirm email with invalid token", %{conn: conn, client: client} do
      {:ok, lv, _html} = live(conn, ~p"/clients/confirm/invalid-token")

      {:ok, conn} =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Client confirmation link is invalid or it has expired"

      refute Profile.get_client!(client.id).confirmed_at
    end
  end
end
