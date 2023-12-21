defmodule Docteur.ProfileFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Docteur.Profile` context.
  """

  def unique_client_email, do: "client#{System.unique_integer()}@example.com"
  def valid_client_password, do: "hello world!"

  def valid_client_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_client_email(),
      password: valid_client_password()
    })
  end

  def client_fixture(attrs \\ %{}) do
    {:ok, client} =
      attrs
      |> valid_client_attributes()
      |> Docteur.Profile.register_client()

    client
  end

  def extract_client_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end
end
