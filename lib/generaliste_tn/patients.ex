defmodule GeneralisteTN.Patients do
  alias GeneralisteTN.Patients.Patient
  alias GeneralisteTN.Repo

  def all() do
    Patient.all()
    |> Repo.all()
  end

  def get(patient_id) do
    Patient.get(patient_id)
    |> Repo.one!()
  end

  def delete_by_id(patient_id) do
    get(patient_id)
    |> Repo.delete()
  end
end
