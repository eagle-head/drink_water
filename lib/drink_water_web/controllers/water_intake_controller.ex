defmodule DrinkWaterWeb.WaterIntakeController do
  use DrinkWaterWeb, :controller

  alias DrinkWater.UserManagement
  alias DrinkWater.HydrationTracking
  alias DrinkWater.HydrationTracking.WaterIntake

  action_fallback DrinkWaterWeb.FallbackController

  @filter_params ~w(start_date end_date min_volume max_volume cursor size sort_field sort_direction)

  def index(conn, %{"user_id" => user_id} = params) do
    filter_params = Map.take(params, @filter_params)

    with {:ok, user} <- UserManagement.get_user(user_id),
         {:ok, page} <- HydrationTracking.list_water_intakes(user.id, filter_params) do
      render(conn, :index, page: page)
    end
  end

  def create(conn, %{"user_id" => user_id, "water_intake" => water_intake_params}) do
    with {:ok, user} <- UserManagement.get_user(user_id),
         {:ok, %WaterIntake{} = water_intake} <-
           HydrationTracking.create_water_intake(user.id, water_intake_params) do
      conn
      |> put_status(:created)
      |> render(:show, water_intake: water_intake)
    end
  end

  def show(conn, %{"user_id" => user_id, "id" => id}) do
    with {:ok, user} <- UserManagement.get_user(user_id),
         {:ok, water_intake} <- HydrationTracking.get_water_intake(user.id, id) do
      render(conn, :show, water_intake: water_intake)
    end
  end

  def update(conn, %{"user_id" => user_id, "id" => id, "water_intake" => water_intake_params}) do
    with {:ok, user} <- UserManagement.get_user(user_id),
         {:ok, water_intake} <- HydrationTracking.get_water_intake(user.id, id),
         {:ok, %WaterIntake{} = water_intake} <-
           HydrationTracking.update_water_intake(water_intake, water_intake_params) do
      render(conn, :show, water_intake: water_intake)
    end
  end

  def delete(conn, %{"user_id" => user_id, "id" => id}) do
    with {:ok, user} <- UserManagement.get_user(user_id),
         {:ok, water_intake} <- HydrationTracking.get_water_intake(user.id, id),
         {:ok, %WaterIntake{}} <- HydrationTracking.delete_water_intake(water_intake) do
      send_resp(conn, :no_content, "")
    end
  end
end
