defmodule Docteur.Profile do
  @moduledoc """
  The Profile context.
  """

  import Ecto.Query, warn: false
  alias Docteur.Repo

  alias Docteur.Profile.{Client, ClientToken, ClientNotifier}

  ## Database getters

  @doc """
  Gets a client by email.

  ## Examples

      iex> get_client_by_email("foo@example.com")
      %Client{}

      iex> get_client_by_email("unknown@example.com")
      nil

  """
  def get_client_by_email(email) when is_binary(email) do
    Repo.get_by(Client, email: email)
  end

  @doc """
  Gets a client by email and password.

  ## Examples

      iex> get_client_by_email_and_password("foo@example.com", "correct_password")
      %Client{}

      iex> get_client_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_client_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    client = Repo.get_by(Client, email: email)
    if Client.valid_password?(client, password), do: client
  end

  @doc """
  Gets a single client.

  Raises `Ecto.NoResultsError` if the Client does not exist.

  ## Examples

      iex> get_client!(123)
      %Client{}

      iex> get_client!(456)
      ** (Ecto.NoResultsError)

  """
  def get_client!(id), do: Repo.get!(Client, id)

  ## Client registration

  @doc """
  Registers a client.

  ## Examples

      iex> register_client(%{field: value})
      {:ok, %Client{}}

      iex> register_client(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_client(attrs) do
    %Client{}
    |> Client.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking client changes.

  ## Examples

      iex> change_client_registration(client)
      %Ecto.Changeset{data: %Client{}}

  """
  def change_client_registration(%Client{} = client, attrs \\ %{}) do
    Client.registration_changeset(client, attrs, hash_password: false, validate_email: false)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the client email.

  ## Examples

      iex> change_client_email(client)
      %Ecto.Changeset{data: %Client{}}

  """
  def change_client_email(client, attrs \\ %{}) do
    Client.email_changeset(client, attrs, validate_email: false)
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_client_email(client, "valid password", %{email: ...})
      {:ok, %Client{}}

      iex> apply_client_email(client, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_client_email(client, password, attrs) do
    client
    |> Client.email_changeset(attrs)
    |> Client.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the client email using the given token.

  If the token matches, the client email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_client_email(client, token) do
    context = "change:#{client.email}"

    with {:ok, query} <- ClientToken.verify_change_email_token_query(token, context),
         %ClientToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(client_email_multi(client, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp client_email_multi(client, email, context) do
    changeset =
      client
      |> Client.email_changeset(%{email: email})
      |> Client.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:client, changeset)
    |> Ecto.Multi.delete_all(:tokens, ClientToken.by_client_and_contexts_query(client, [context]))
  end

  @doc ~S"""
  Delivers the update email instructions to the given client.

  ## Examples

      iex> deliver_client_update_email_instructions(client, current_email, &url(~p"/clients/settings/confirm_email/#{&1})")
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_client_update_email_instructions(%Client{} = client, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, client_token} = ClientToken.build_email_token(client, "change:#{current_email}")

    Repo.insert!(client_token)
    ClientNotifier.deliver_update_email_instructions(client, update_email_url_fun.(encoded_token))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the client password.

  ## Examples

      iex> change_client_password(client)
      %Ecto.Changeset{data: %Client{}}

  """
  def change_client_password(client, attrs \\ %{}) do
    Client.password_changeset(client, attrs, hash_password: false)
  end

  @doc """
  Updates the client password.

  ## Examples

      iex> update_client_password(client, "valid password", %{password: ...})
      {:ok, %Client{}}

      iex> update_client_password(client, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_client_password(client, password, attrs) do
    changeset =
      client
      |> Client.password_changeset(attrs)
      |> Client.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:client, changeset)
    |> Ecto.Multi.delete_all(:tokens, ClientToken.by_client_and_contexts_query(client, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{client: client}} -> {:ok, client}
      {:error, :client, changeset, _} -> {:error, changeset}
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_client_session_token(client) do
    {token, client_token} = ClientToken.build_session_token(client)
    Repo.insert!(client_token)
    token
  end

  @doc """
  Gets the client with the given signed token.
  """
  def get_client_by_session_token(token) do
    {:ok, query} = ClientToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_client_session_token(token) do
    Repo.delete_all(ClientToken.by_token_and_context_query(token, "session"))
    :ok
  end

  ## Confirmation

  @doc ~S"""
  Delivers the confirmation email instructions to the given client.

  ## Examples

      iex> deliver_client_confirmation_instructions(client, &url(~p"/clients/confirm/#{&1}"))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_client_confirmation_instructions(confirmed_client, &url(~p"/clients/confirm/#{&1}"))
      {:error, :already_confirmed}

  """
  def deliver_client_confirmation_instructions(%Client{} = client, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if client.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, client_token} = ClientToken.build_email_token(client, "confirm")
      Repo.insert!(client_token)
      ClientNotifier.deliver_confirmation_instructions(client, confirmation_url_fun.(encoded_token))
    end
  end

  @doc """
  Confirms a client by the given token.

  If the token matches, the client account is marked as confirmed
  and the token is deleted.
  """
  def confirm_client(token) do
    with {:ok, query} <- ClientToken.verify_email_token_query(token, "confirm"),
         %Client{} = client <- Repo.one(query),
         {:ok, %{client: client}} <- Repo.transaction(confirm_client_multi(client)) do
      {:ok, client}
    else
      _ -> :error
    end
  end

  defp confirm_client_multi(client) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:client, Client.confirm_changeset(client))
    |> Ecto.Multi.delete_all(:tokens, ClientToken.by_client_and_contexts_query(client, ["confirm"]))
  end

  ## Reset password

  @doc ~S"""
  Delivers the reset password email to the given client.

  ## Examples

      iex> deliver_client_reset_password_instructions(client, &url(~p"/clients/reset_password/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_client_reset_password_instructions(%Client{} = client, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, client_token} = ClientToken.build_email_token(client, "reset_password")
    Repo.insert!(client_token)
    ClientNotifier.deliver_reset_password_instructions(client, reset_password_url_fun.(encoded_token))
  end

  @doc """
  Gets the client by reset password token.

  ## Examples

      iex> get_client_by_reset_password_token("validtoken")
      %Client{}

      iex> get_client_by_reset_password_token("invalidtoken")
      nil

  """
  def get_client_by_reset_password_token(token) do
    with {:ok, query} <- ClientToken.verify_email_token_query(token, "reset_password"),
         %Client{} = client <- Repo.one(query) do
      client
    else
      _ -> nil
    end
  end

  @doc """
  Resets the client password.

  ## Examples

      iex> reset_client_password(client, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %Client{}}

      iex> reset_client_password(client, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_client_password(client, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:client, Client.password_changeset(client, attrs))
    |> Ecto.Multi.delete_all(:tokens, ClientToken.by_client_and_contexts_query(client, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{client: client}} -> {:ok, client}
      {:error, :client, changeset, _} -> {:error, changeset}
    end
  end
end
