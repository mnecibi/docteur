defmodule GeneralisteTN.Patients.Patient do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias __MODULE__

  @primary_key {:patient_id, Ecto.UUID, autogenerate: false}
  schema "patient" do
    field :first_name, :string
    field :last_name, :string
    field :birthdate, :date
  end

  def changeset(p \\ %Patient{}, params) do
    p
    |> cast(params, __schema__(:fields))
    |> validate_required([:patient_id, :first_name, :last_name, :birthdate])
  end

  def all() do
    from(p in Patient)
  end

  def get(patient_id) do
    from(p in Patient, where: p.patient_id == ^patient_id)
  end
end
