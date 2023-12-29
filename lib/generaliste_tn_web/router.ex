defmodule GeneralisteTNWeb.Router do
  use GeneralisteTNWeb, :router

  import GeneralisteTNWeb.ClientAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {GeneralisteTNWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_client
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Other scopes may use custom stacks.
  # scope "/api", GeneralisteTNWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:generaliste_tn, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: GeneralisteTNWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", GeneralisteTNWeb do
    pipe_through [:browser, :redirect_if_client_is_authenticated]

    live_session :redirect_if_client_is_authenticated,
      on_mount: [{GeneralisteTNWeb.ClientAuth, :redirect_if_client_is_authenticated}] do
      live "/clients/register", ClientRegistrationLive, :new
      live "/clients/log_in", ClientLoginLive, :new
      live "/clients/reset_password", ClientForgotPasswordLive, :new
      live "/clients/reset_password/:token", ClientResetPasswordLive, :edit
    end

    post "/clients/log_in", ClientSessionController, :create
  end

  scope "/", GeneralisteTNWeb do
    pipe_through [:browser, :require_authenticated_client]

    live_session :require_authenticated_client,
      on_mount: [{GeneralisteTNWeb.ClientAuth, :ensure_authenticated}] do
      live "/", HomeLive, :home
      live "/patient/:patient_id", PatientLive
      live "/clients/settings", ClientSettingsLive, :edit
      live "/clients/settings/confirm_email/:token", ClientSettingsLive, :confirm_email
    end
  end

  scope "/", GeneralisteTNWeb do
    pipe_through [:browser]

    delete "/clients/log_out", ClientSessionController, :delete

    live_session :current_client,
      on_mount: [{GeneralisteTNWeb.ClientAuth, :mount_current_client}] do
      live "/clients/confirm/:token", ClientConfirmationLive, :edit
      live "/clients/confirm", ClientConfirmationInstructionsLive, :new
    end
  end
end
