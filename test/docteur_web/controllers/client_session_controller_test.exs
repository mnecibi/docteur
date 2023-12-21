defmodule DocteurWeb.ClientSessionControllerTest do
  use DocteurWeb.ConnCase, async: true

  import Docteur.ProfileFixtures

  setup do
    %{client: client_fixture()}
  end

  describe "POST /clients/log_in" do
    test "logs the client in", %{conn: conn, client: client} do
      conn =
        post(conn, ~p"/clients/log_in", %{
          "client" => %{"email" => client.email, "password" => valid_client_password()}
        })

      assert get_session(conn, :client_token)
      assert redirected_to(conn) == ~p"/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)
      assert response =~ client.email
      assert response =~ ~p"/clients/settings"
      assert response =~ ~p"/clients/log_out"
    end

    test "logs the client in with remember me", %{conn: conn, client: client} do
      conn =
        post(conn, ~p"/clients/log_in", %{
          "client" => %{
            "email" => client.email,
            "password" => valid_client_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["_docteur_web_client_remember_me"]
      assert redirected_to(conn) == ~p"/"
    end

    test "logs the client in with return to", %{conn: conn, client: client} do
      conn =
        conn
        |> init_test_session(client_return_to: "/foo/bar")
        |> post(~p"/clients/log_in", %{
          "client" => %{
            "email" => client.email,
            "password" => valid_client_password()
          }
        })

      assert redirected_to(conn) == "/foo/bar"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Welcome back!"
    end

    test "login following registration", %{conn: conn, client: client} do
      conn =
        conn
        |> post(~p"/clients/log_in", %{
          "_action" => "registered",
          "client" => %{
            "email" => client.email,
            "password" => valid_client_password()
          }
        })

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Account created successfully"
    end

    test "login following password update", %{conn: conn, client: client} do
      conn =
        conn
        |> post(~p"/clients/log_in", %{
          "_action" => "password_updated",
          "client" => %{
            "email" => client.email,
            "password" => valid_client_password()
          }
        })

      assert redirected_to(conn) == ~p"/clients/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Password updated successfully"
    end

    test "redirects to login page with invalid credentials", %{conn: conn} do
      conn =
        post(conn, ~p"/clients/log_in", %{
          "client" => %{"email" => "invalid@email.com", "password" => "invalid_password"}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
      assert redirected_to(conn) == ~p"/clients/log_in"
    end
  end

  describe "DELETE /clients/log_out" do
    test "logs the client out", %{conn: conn, client: client} do
      conn = conn |> log_in_client(client) |> delete(~p"/clients/log_out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :client_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end

    test "succeeds even if the client is not logged in", %{conn: conn} do
      conn = delete(conn, ~p"/clients/log_out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :client_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end
  end
end
