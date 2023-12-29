defmodule GeneralisteTNWeb.PatientLive do
  use GeneralisteTNWeb, :live_view

  alias GeneralisteTN.Patients

  def render(assigns) do
    ~H"""
    <h2 class="text-lg font-bold">Patient Information :</h2>
    <div><%= "Name: #{@patient.first_name} #{@patient.last_name}" %></div>
    <div><%= "Birthdate: #{@patient.birthdate}" %></div>
    """
  end

  def mount(%{"patient_id" => patient_id}, _session, socket) do
    socket
    |> assign(patient: Patients.get(patient_id))
    |> ok()
  end
end
