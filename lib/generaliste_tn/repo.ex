defmodule GeneralisteTN.Repo do
  use Ecto.Repo,
    otp_app: :generaliste_tn,
    adapter: Ecto.Adapters.Postgres
end
