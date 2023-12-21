defmodule DocteurWeb.ClientConfirmationLive do
  use DocteurWeb, :live_view

  alias Docteur.Profile

  def render(%{live_action: :edit} = assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">Confirm Account</.header>

      <.simple_form for={@form} id="confirmation_form" phx-submit="confirm_account">
        <.input field={@form[:token]} type="hidden" />
        <:actions>
          <.button phx-disable-with="Confirming..." class="w-full">Confirm my account</.button>
        </:actions>
      </.simple_form>

      <p class="text-center mt-4">
        <.link href={~p"/clients/register"}>Register</.link>
        | <.link href={~p"/clients/log_in"}>Log in</.link>
      </p>
    </div>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    form = to_form(%{"token" => token}, as: "client")
    {:ok, assign(socket, form: form), temporary_assigns: [form: nil]}
  end

  # Do not log in the client after confirmation to avoid a
  # leaked token giving the client access to the account.
  def handle_event("confirm_account", %{"client" => %{"token" => token}}, socket) do
    case Profile.confirm_client(token) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Client confirmed successfully.")
         |> redirect(to: ~p"/")}

      :error ->
        # If there is a current client and the account was already confirmed,
        # then odds are that the confirmation link was already visited, either
        # by some automation or by the client themselves, so we redirect without
        # a warning message.
        case socket.assigns do
          %{current_client: %{confirmed_at: confirmed_at}} when not is_nil(confirmed_at) ->
            {:noreply, redirect(socket, to: ~p"/")}

          %{} ->
            {:noreply,
             socket
             |> put_flash(:error, "Client confirmation link is invalid or it has expired.")
             |> redirect(to: ~p"/")}
        end
    end
  end
end
