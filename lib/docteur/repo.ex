defmodule Docteur.Repo do
  use Ecto.Repo,
    otp_app: :docteur,
    adapter: Ecto.Adapters.Postgres
end
