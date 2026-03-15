defmodule DrinkWater.HydrationTrackingFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `DrinkWater.HydrationTracking` context.
  """

  import DrinkWater.UserManagementFixtures

  @doc """
  Generate a water intake for a user.
  """
  def water_intake_fixture(user_id \\ :new, attrs \\ %{}) do
    user_id = if user_id == :new, do: user_fixture().id, else: user_id

    {:ok, water_intake} =
      attrs
      |> Enum.into(%{
        date_time_utc: ~U[2026-03-14 12:00:00Z],
        volume: 250,
        volume_unit: :ml
      })
      |> then(&DrinkWater.HydrationTracking.create_water_intake(user_id, &1))

    water_intake
  end
end
