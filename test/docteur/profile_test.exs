defmodule Docteur.ProfileTest do
  use Docteur.DataCase

  alias Docteur.Profile

  import Docteur.ProfileFixtures
  alias Docteur.Profile.{Client, ClientToken}

  describe "get_client_by_email/1" do
    test "does not return the client if the email does not exist" do
      refute Profile.get_client_by_email("unknown@example.com")
    end

    test "returns the client if the email exists" do
      %{id: id} = client = client_fixture()
      assert %Client{id: ^id} = Profile.get_client_by_email(client.email)
    end
  end

  describe "get_client_by_email_and_password/2" do
    test "does not return the client if the email does not exist" do
      refute Profile.get_client_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the client if the password is not valid" do
      client = client_fixture()
      refute Profile.get_client_by_email_and_password(client.email, "invalid")
    end

    test "returns the client if the email and password are valid" do
      %{id: id} = client = client_fixture()

      assert %Client{id: ^id} =
               Profile.get_client_by_email_and_password(client.email, valid_client_password())
    end
  end

  describe "get_client!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Profile.get_client!(-1)
      end
    end

    test "returns the client with the given id" do
      %{id: id} = client = client_fixture()
      assert %Client{id: ^id} = Profile.get_client!(client.id)
    end
  end

  describe "register_client/1" do
    test "requires email and password to be set" do
      {:error, changeset} = Profile.register_client(%{})

      assert %{
               password: ["can't be blank"],
               email: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "validates email and password when given" do
      {:error, changeset} = Profile.register_client(%{email: "not valid", password: "not valid"})

      assert %{
               email: ["must have the @ sign and no spaces"],
               password: ["should be at least 12 character(s)"]
             } = errors_on(changeset)
    end

    test "validates maximum values for email and password for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Profile.register_client(%{email: too_long, password: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates email uniqueness" do
      %{email: email} = client_fixture()
      {:error, changeset} = Profile.register_client(%{email: email})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the upper cased email too, to check that email case is ignored.
      {:error, changeset} = Profile.register_client(%{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers clients with a hashed password" do
      email = unique_client_email()
      {:ok, client} = Profile.register_client(valid_client_attributes(email: email))
      assert client.email == email
      assert is_binary(client.hashed_password)
      assert is_nil(client.confirmed_at)
      assert is_nil(client.password)
    end
  end

  describe "change_client_registration/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = changeset = Profile.change_client_registration(%Client{})
      assert changeset.required == [:password, :email]
    end

    test "allows fields to be set" do
      email = unique_client_email()
      password = valid_client_password()

      changeset =
        Profile.change_client_registration(
          %Client{},
          valid_client_attributes(email: email, password: password)
        )

      assert changeset.valid?
      assert get_change(changeset, :email) == email
      assert get_change(changeset, :password) == password
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "change_client_email/2" do
    test "returns a client changeset" do
      assert %Ecto.Changeset{} = changeset = Profile.change_client_email(%Client{})
      assert changeset.required == [:email]
    end
  end

  describe "apply_client_email/3" do
    setup do
      %{client: client_fixture()}
    end

    test "requires email to change", %{client: client} do
      {:error, changeset} = Profile.apply_client_email(client, valid_client_password(), %{})
      assert %{email: ["did not change"]} = errors_on(changeset)
    end

    test "validates email", %{client: client} do
      {:error, changeset} =
        Profile.apply_client_email(client, valid_client_password(), %{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum value for email for security", %{client: client} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Profile.apply_client_email(client, valid_client_password(), %{email: too_long})

      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness", %{client: client} do
      %{email: email} = client_fixture()
      password = valid_client_password()

      {:error, changeset} = Profile.apply_client_email(client, password, %{email: email})

      assert "has already been taken" in errors_on(changeset).email
    end

    test "validates current password", %{client: client} do
      {:error, changeset} =
        Profile.apply_client_email(client, "invalid", %{email: unique_client_email()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "applies the email without persisting it", %{client: client} do
      email = unique_client_email()
      {:ok, client} = Profile.apply_client_email(client, valid_client_password(), %{email: email})
      assert client.email == email
      assert Profile.get_client!(client.id).email != email
    end
  end

  describe "deliver_client_update_email_instructions/3" do
    setup do
      %{client: client_fixture()}
    end

    test "sends token through notification", %{client: client} do
      token =
        extract_client_token(fn url ->
          Profile.deliver_client_update_email_instructions(client, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert client_token = Repo.get_by(ClientToken, token: :crypto.hash(:sha256, token))
      assert client_token.client_id == client.id
      assert client_token.sent_to == client.email
      assert client_token.context == "change:current@example.com"
    end
  end

  describe "update_client_email/2" do
    setup do
      client = client_fixture()
      email = unique_client_email()

      token =
        extract_client_token(fn url ->
          Profile.deliver_client_update_email_instructions(%{client | email: email}, client.email, url)
        end)

      %{client: client, token: token, email: email}
    end

    test "updates the email with a valid token", %{client: client, token: token, email: email} do
      assert Profile.update_client_email(client, token) == :ok
      changed_client = Repo.get!(Client, client.id)
      assert changed_client.email != client.email
      assert changed_client.email == email
      assert changed_client.confirmed_at
      assert changed_client.confirmed_at != client.confirmed_at
      refute Repo.get_by(ClientToken, client_id: client.id)
    end

    test "does not update email with invalid token", %{client: client} do
      assert Profile.update_client_email(client, "oops") == :error
      assert Repo.get!(Client, client.id).email == client.email
      assert Repo.get_by(ClientToken, client_id: client.id)
    end

    test "does not update email if client email changed", %{client: client, token: token} do
      assert Profile.update_client_email(%{client | email: "current@example.com"}, token) == :error
      assert Repo.get!(Client, client.id).email == client.email
      assert Repo.get_by(ClientToken, client_id: client.id)
    end

    test "does not update email if token expired", %{client: client, token: token} do
      {1, nil} = Repo.update_all(ClientToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Profile.update_client_email(client, token) == :error
      assert Repo.get!(Client, client.id).email == client.email
      assert Repo.get_by(ClientToken, client_id: client.id)
    end
  end

  describe "change_client_password/2" do
    test "returns a client changeset" do
      assert %Ecto.Changeset{} = changeset = Profile.change_client_password(%Client{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        Profile.change_client_password(%Client{}, %{
          "password" => "new valid password"
        })

      assert changeset.valid?
      assert get_change(changeset, :password) == "new valid password"
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_client_password/3" do
    setup do
      %{client: client_fixture()}
    end

    test "validates password", %{client: client} do
      {:error, changeset} =
        Profile.update_client_password(client, valid_client_password(), %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{client: client} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Profile.update_client_password(client, valid_client_password(), %{password: too_long})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates current password", %{client: client} do
      {:error, changeset} =
        Profile.update_client_password(client, "invalid", %{password: valid_client_password()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "updates the password", %{client: client} do
      {:ok, client} =
        Profile.update_client_password(client, valid_client_password(), %{
          password: "new valid password"
        })

      assert is_nil(client.password)
      assert Profile.get_client_by_email_and_password(client.email, "new valid password")
    end

    test "deletes all tokens for the given client", %{client: client} do
      _ = Profile.generate_client_session_token(client)

      {:ok, _} =
        Profile.update_client_password(client, valid_client_password(), %{
          password: "new valid password"
        })

      refute Repo.get_by(ClientToken, client_id: client.id)
    end
  end

  describe "generate_client_session_token/1" do
    setup do
      %{client: client_fixture()}
    end

    test "generates a token", %{client: client} do
      token = Profile.generate_client_session_token(client)
      assert client_token = Repo.get_by(ClientToken, token: token)
      assert client_token.context == "session"

      # Creating the same token for another client should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%ClientToken{
          token: client_token.token,
          client_id: client_fixture().id,
          context: "session"
        })
      end
    end
  end

  describe "get_client_by_session_token/1" do
    setup do
      client = client_fixture()
      token = Profile.generate_client_session_token(client)
      %{client: client, token: token}
    end

    test "returns client by token", %{client: client, token: token} do
      assert session_client = Profile.get_client_by_session_token(token)
      assert session_client.id == client.id
    end

    test "does not return client for invalid token" do
      refute Profile.get_client_by_session_token("oops")
    end

    test "does not return client for expired token", %{token: token} do
      {1, nil} = Repo.update_all(ClientToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Profile.get_client_by_session_token(token)
    end
  end

  describe "delete_client_session_token/1" do
    test "deletes the token" do
      client = client_fixture()
      token = Profile.generate_client_session_token(client)
      assert Profile.delete_client_session_token(token) == :ok
      refute Profile.get_client_by_session_token(token)
    end
  end

  describe "deliver_client_confirmation_instructions/2" do
    setup do
      %{client: client_fixture()}
    end

    test "sends token through notification", %{client: client} do
      token =
        extract_client_token(fn url ->
          Profile.deliver_client_confirmation_instructions(client, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert client_token = Repo.get_by(ClientToken, token: :crypto.hash(:sha256, token))
      assert client_token.client_id == client.id
      assert client_token.sent_to == client.email
      assert client_token.context == "confirm"
    end
  end

  describe "confirm_client/1" do
    setup do
      client = client_fixture()

      token =
        extract_client_token(fn url ->
          Profile.deliver_client_confirmation_instructions(client, url)
        end)

      %{client: client, token: token}
    end

    test "confirms the email with a valid token", %{client: client, token: token} do
      assert {:ok, confirmed_client} = Profile.confirm_client(token)
      assert confirmed_client.confirmed_at
      assert confirmed_client.confirmed_at != client.confirmed_at
      assert Repo.get!(Client, client.id).confirmed_at
      refute Repo.get_by(ClientToken, client_id: client.id)
    end

    test "does not confirm with invalid token", %{client: client} do
      assert Profile.confirm_client("oops") == :error
      refute Repo.get!(Client, client.id).confirmed_at
      assert Repo.get_by(ClientToken, client_id: client.id)
    end

    test "does not confirm email if token expired", %{client: client, token: token} do
      {1, nil} = Repo.update_all(ClientToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Profile.confirm_client(token) == :error
      refute Repo.get!(Client, client.id).confirmed_at
      assert Repo.get_by(ClientToken, client_id: client.id)
    end
  end

  describe "deliver_client_reset_password_instructions/2" do
    setup do
      %{client: client_fixture()}
    end

    test "sends token through notification", %{client: client} do
      token =
        extract_client_token(fn url ->
          Profile.deliver_client_reset_password_instructions(client, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert client_token = Repo.get_by(ClientToken, token: :crypto.hash(:sha256, token))
      assert client_token.client_id == client.id
      assert client_token.sent_to == client.email
      assert client_token.context == "reset_password"
    end
  end

  describe "get_client_by_reset_password_token/1" do
    setup do
      client = client_fixture()

      token =
        extract_client_token(fn url ->
          Profile.deliver_client_reset_password_instructions(client, url)
        end)

      %{client: client, token: token}
    end

    test "returns the client with valid token", %{client: %{id: id}, token: token} do
      assert %Client{id: ^id} = Profile.get_client_by_reset_password_token(token)
      assert Repo.get_by(ClientToken, client_id: id)
    end

    test "does not return the client with invalid token", %{client: client} do
      refute Profile.get_client_by_reset_password_token("oops")
      assert Repo.get_by(ClientToken, client_id: client.id)
    end

    test "does not return the client if token expired", %{client: client, token: token} do
      {1, nil} = Repo.update_all(ClientToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Profile.get_client_by_reset_password_token(token)
      assert Repo.get_by(ClientToken, client_id: client.id)
    end
  end

  describe "reset_client_password/2" do
    setup do
      %{client: client_fixture()}
    end

    test "validates password", %{client: client} do
      {:error, changeset} =
        Profile.reset_client_password(client, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{client: client} do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Profile.reset_client_password(client, %{password: too_long})
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{client: client} do
      {:ok, updated_client} = Profile.reset_client_password(client, %{password: "new valid password"})
      assert is_nil(updated_client.password)
      assert Profile.get_client_by_email_and_password(client.email, "new valid password")
    end

    test "deletes all tokens for the given client", %{client: client} do
      _ = Profile.generate_client_session_token(client)
      {:ok, _} = Profile.reset_client_password(client, %{password: "new valid password"})
      refute Repo.get_by(ClientToken, client_id: client.id)
    end
  end

  describe "inspect/2 for the Client module" do
    test "does not include password" do
      refute inspect(%Client{password: "123456"}) =~ "password: \"123456\""
    end
  end
end
