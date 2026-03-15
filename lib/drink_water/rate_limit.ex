defmodule DrinkWater.RateLimit do
  use Hammer, backend: :ets
end
