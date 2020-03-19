defmodule ExRogue.Repo do
  use Ecto.Repo,
    otp_app: :ex_rogue,
    adapter: Ecto.Adapters.Postgres
end
