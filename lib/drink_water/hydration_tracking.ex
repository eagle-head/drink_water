defmodule DrinkWater.HydrationTracking do
  @moduledoc """
  The HydrationTracking context.
  """

  import Ecto.Query, warn: false
  alias DrinkWater.Repo

  alias DrinkWater.HydrationTracking.WaterIntake

  @doc """
  Lists water intakes for a user.
  """
  def list_water_intakes(user_id) do
    WaterIntake
    |> where(user_id: ^user_id)
    |> order_by(desc: :date_time_utc)
    |> Repo.all()
  end

  @doc """
  Gets a single water intake scoped by user.

  Returns `{:ok, %WaterIntake{}}` or `{:error, :not_found}`.
  """
  def get_water_intake(user_id, id) do
    case Repo.get_by(WaterIntake, id: id, user_id: user_id) do
      nil -> {:error, :not_found}
      water_intake -> {:ok, water_intake}
    end
  end

  @doc """
  Creates a water intake for a user.

  The `user_id` is set programmatically, not through user input.
  """
  def create_water_intake(user_id, attrs) do
    %WaterIntake{user_id: user_id}
    |> WaterIntake.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a water intake.
  """
  def update_water_intake(%WaterIntake{} = water_intake, attrs) do
    water_intake
    |> WaterIntake.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a water intake.
  """
  def delete_water_intake(%WaterIntake{} = water_intake) do
    Repo.delete(water_intake)
  end
end
