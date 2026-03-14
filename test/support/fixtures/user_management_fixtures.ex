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
        email: "user#{System.unique_integer([:positive])}@example.com",
        first_name: "John",
        last_name: "Doe",
        birth_date: ~D[1990-05-15],
        biological_sex: :male,
        weight: "75.0",
        weight_unit: :kg,
        height: "175.0",
        height_unit: :cm
      })
      |> DrinkWater.UserManagement.create_user()

    user
  end
end
