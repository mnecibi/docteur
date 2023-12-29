defmodule GeneralisteTN.Repo.Migrations.AddPatient do
  use Ecto.Migration

  def change do
    create table(:patient, primary_key: false) do
      add :patient_id, :uuid, primary_key: true
      add :first_name, :string
      add :last_name, :string
      add :birthdate, :date
    end
  end
end
