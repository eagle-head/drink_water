defmodule DrinkWater.UserManagementFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `DrinkWater.UserManagement` context.
  """

  @doc """
  Generate a user.
  """
  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{
        biological_sex: 42,
        birth_date: ~D[2026-03-13],
        email: "some email",
        first_name: "some first_name",
        height: "120.5",
        height_unit: 42,
        last_name: "some last_name",
        weight: "120.5",
        weight_unit: 42
      })
      |> DrinkWater.UserManagement.create_user()

    user
  end
end
