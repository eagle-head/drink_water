defmodule DrinkWaterWeb.UserJSON do
  alias DrinkWater.UserManagement.User

  @doc """
  Renders a list of users.
  """
  def index(%{users: users}) do
    %{data: for(user <- users, do: data(user))}
  end

  @doc """
  Renders a single user.
  """
  def show(%{user: user}) do
    %{data: data(user)}
  end

  defp data(%User{} = user) do
    %{
      id: user.id,
      email: user.email,
      first_name: user.first_name,
      last_name: user.last_name,
      birth_date: user.birth_date,
      biological_sex: user.biological_sex,
      weight: Decimal.to_float(user.weight),
      weight_unit: user.weight_unit,
      height: Decimal.to_float(user.height),
      height_unit: user.height_unit
    }
  end
end
