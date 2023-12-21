defmodule DocteurWeb.HomeLive do
  use DocteurWeb, :live_view

  def render(assigns) do
    ~H"""
    - Add client
    - List clients
    """
  end

  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
