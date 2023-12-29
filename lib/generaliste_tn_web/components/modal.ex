defmodule GeneralisteTNWeb.Components.Modal do
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  import GeneralisteTNWeb.CoreComponents

  attr :id, :string, required: true
  attr :show, :boolean, default: true
  attr :class, :string, default: ""
  attr :toggle_show_event, :string, required: true
  attr :on_cancel, :any, default: %JS{}
  attr :on_confirm, JS, default: %JS{}
  attr :confirm_button_prio, :string, default: "primary"
  attr :confirm_disabled?, :boolean, default: false
  attr :type, :string, default: "default", values: ["default", "dark"]

  slot(:inner_block, required: true)
  slot(:title)
  slot(:subtitle)
  slot(:confirm)
  slot(:cancel)

  def modal(assigns) do
    ~H"""
    <div :if={@show} id={@id} phx-mounted={@show && show_modal(@id)} class="relative z-50 hidden">
      <div
        id={"#{@id}-bg"}
        class="fixed inset-0 bg-gray-500/50 transition-opacity"
        aria-hidden="true"
      />
      <div
        class="fixed inset-0 overflow-y-auto"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class="flex min-h-full items-center justify-center">
          <div class={"w-full #{@class}"}>
            <.focus_wrap
              id={"#{@id}-container"}
              phx-window-keydown={@toggle_show_event}
              phx-key="escape"
              phx-click-away={@toggle_show_event}
              class={"hidden overflow-hidden relative rounded-2xl bg-white shadow-lg shadow-zinc-700/10 ring-1 ring-zinc-700/10 transition #{if @type == "dark", do: "bg-grey-200"}"}
            >
              <div class="absolute top-6 right-5">
                <button
                  phx-click={@toggle_show_event}
                  type="button"
                  class="-m-3 flex-none p-3 opacity-20 hover:opacity-40"
                >
                  <.icon name="hero-x_mark" />
                </button>
              </div>
              <div id={"#{@id}-content"}>
                <header
                  :if={@title != []}
                  class={"px-6 py-4 border-b border-gray-300 #{if @type == "dark", do: "border-none"}"}
                >
                  <h1 id={"#{@id}-title"} class="text-lg font-semibold leading-8 text-zinc-800">
                    <%= render_slot(@title) %>
                  </h1>
                  <p :if={@subtitle != []} class="mt-2 text-sm leading-6 text-zinc-600">
                    <%= render_slot(@subtitle) %>
                  </p>
                </header>
                <%= render_slot(@inner_block) %>
                <div
                  :if={@confirm != [] or @cancel != []}
                  class={"py-3 px-6 bg-gray-100 rounded-b-2xl flex items-center gap-3 #{if @type == "dark", do: "bg-grey-300"}"}
                >
                  <.button
                    :for={confirm <- @confirm}
                    phx-click={@on_confirm}
                    disabled={@confirm_disabled?}
                  >
                    <%= render_slot(confirm) %>
                  </.button>
                  <.button :for={cancel <- @cancel} phx-click={@on_cancel}>
                    <%= render_slot(cancel) %>
                  </.button>
                </div>
              </div>
            </.focus_wrap>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(to: "##{id}")
    |> JS.show(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> show("##{id}-container")
    |> JS.focus_first(to: "##{id}-content")
  end
end
