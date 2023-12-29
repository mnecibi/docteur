defmodule GeneralisteTNWeb.HomeLive do
  use GeneralisteTNWeb, :live_view

  alias GeneralisteTN.Patients
  alias GeneralisteTN.Patients.Patient

  def render(assigns) do
    ~H"""
    <.patients patients={@patients} />
    <.add_patient_modal show_add_patient_modal={@show_add_patient_modal} changeset={@changeset} />
    """
  end

  def handle_event("toggle_patient_modal", _params, socket) do
    socket
    |> update(:show_add_patient_modal, fn show_modal? -> !show_modal? end)
    |> noreply()
  end

  def handle_event("delete", %{"id" => patient_id}, socket) do
    case Patients.delete_by_id(patient_id) do
      {:ok, _} ->
        socket
        |> assign(patients: Patients.all())
        |> noreply()
    end
  end

  def handle_event("validate", %{"patient" => params}, socket) do
    socket
    |> assign(changeset: Patient.changeset(params) |> Map.put(:action, :validate))
    |> noreply()
  end

  def handle_event("submit", %{"patient" => params}, socket) do
    case Patient.changeset(params) do
      %{valid?: true} = changeset ->
        {:ok, _} =
          GeneralisteTN.Repo.insert(changeset)

        socket
        |> push_navigate(to: "/")
        |> noreply()

      changeset ->
        socket
        |> assign(changeset: changeset |> Map.put(:action, :validate))
        |> noreply()
    end
  end

  def mount(_params, _session, socket) do
    socket
    |> assign(
      patients: Patients.all(),
      show_add_patient_modal: false,
      changeset: Patient.changeset(%{patient_id: Ecto.UUID.generate()})
    )
    |> ok()
  end

  defp patients(assigns) do
    ~H"""
    <div class="flex items-center justify-between mb-6">
      <div class="text-lg font-bold">Patients:</div>
      <.button phx-click="toggle_patient_modal">Add patient</.button>
    </div>
    <div class="flex flex-col gap-2">
      <div class="hidden last:block">
        No patients
      </div>
      <.patient :for={patient <- @patients} patient={patient} />
    </div>
    """
  end

  defp patient(assigns) do
    ~H"""
    <div class="flex items-center justify-between">
      <div class="flex gap-3">
        <%= @patient.first_name %>
        <%= @patient.last_name %>
        <%= @patient.birthdate %>
      </div>
      <.link navigate={~p"/patient/#{@patient.patient_id}"}>View</.link>
      <.button phx-click="delete" phx-value-id={@patient.patient_id}>Delete</.button>
    </div>
    """
  end

  defp add_patient_modal(assigns) do
    ~H"""
    <.modal
      class="max-w-xl"
      id="add_patient_modal"
      show={@show_add_patient_modal}
      toggle_show_event="toggle_patient_modal"
    >
      <.form
        :let={f}
        for={@changeset}
        as={:patient}
        phx-change="validate"
        phx-submit="submit"
        class="flex flex-col gap-3 p-6"
      >
        <%= Phoenix.HTML.Form.hidden_input(f, :patient_id) %>
        <.input field={f[:first_name]} label="First name" />
        <.input field={f[:last_name]} label="Last name" />
        <.input field={f[:birthdate]} type="date" label="Date of birth" max={Date.utc_today()} />

        <.button type="submit">Add</.button>
      </.form>
    </.modal>
    """
  end
end
