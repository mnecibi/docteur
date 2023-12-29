defmodule GeneralisteTNWeb.ClientConfirmationInstructionsLiveTest do
  use GeneralisteTNWeb.ConnCase

  import Phoenix.LiveViewTest
  import GeneralisteTN.ProfileFixtures

  alias GeneralisteTN.Profile
  alias GeneralisteTN.Repo

  setup do
    %{client: client_fixture()}
  end

  describe "Resend confirmation" do
    test "renders the resend confirmation page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/clients/confirm")
      assert html =~ "Resend confirmation instructions"
    end

    test "sends a new confirmation token", %{conn: conn, client: client} do
      {:ok, lv, _html} = live(conn, ~p"/clients/confirm")

      {:ok, conn} =
        lv
        |> form("#resend_confirmation_form", client: %{email: client.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      assert Repo.get_by!(Profile.ClientToken, client_id: client.id).context == "confirm"
    end

    test "does not send confirmation token if client is confirmed", %{conn: conn, client: client} do
      Repo.update!(Profile.Client.confirm_changeset(client))

      {:ok, lv, _html} = live(conn, ~p"/clients/confirm")

      {:ok, conn} =
        lv
        |> form("#resend_confirmation_form", client: %{email: client.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      refute Repo.get_by(Profile.ClientToken, client_id: client.id)
    end

    test "does not send confirmation token if email is invalid", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/clients/confirm")

      {:ok, conn} =
        lv
        |> form("#resend_confirmation_form", client: %{email: "unknown@example.com"})
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      assert Repo.all(Profile.ClientToken) == []
    end
  end
end
