defmodule GeneralisteTN.Repo.Migrations.CreateClientsAuthTables do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    create table(:clients) do
      add :email, :citext, null: false
      add :hashed_password, :string, null: false
      add :confirmed_at, :naive_datetime
      timestamps(type: :utc_datetime)
    end

    create unique_index(:clients, [:email])

    create table(:clients_tokens) do
      add :client_id, references(:clients, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      timestamps(updated_at: false)
    end

    create index(:clients_tokens, [:client_id])
    create unique_index(:clients_tokens, [:context, :token])
  end
end
