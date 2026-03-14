defmodule DrinkWater.Repo do
  use Ecto.Repo,
    otp_app: :drink_water,
    adapter: Ecto.Adapters.Postgres
end
