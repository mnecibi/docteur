defmodule GeneralisteTNWeb.ClientSessionController do
  use GeneralisteTNWeb, :controller

  alias GeneralisteTN.Profile
  alias GeneralisteTNWeb.ClientAuth

  def create(conn, %{"_action" => "registered"} = params) do
    create(conn, params, "Account created successfully!")
  end

  def create(conn, %{"_action" => "password_updated"} = params) do
    conn
    |> put_session(:client_return_to, ~p"/clients/settings")
    |> create(params, "Password updated successfully!")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  defp create(conn, %{"client" => client_params}, info) do
    %{"email" => email, "password" => password} = client_params

    if client = Profile.get_client_by_email_and_password(email, password) do
      conn
      |> put_flash(:info, info)
      |> ClientAuth.log_in_client(client, client_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      conn
      |> put_flash(:error, "Invalid email or password")
      |> put_flash(:email, String.slice(email, 0, 160))
      |> redirect(to: ~p"/clients/log_in")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> ClientAuth.log_out_client()
  end
end
