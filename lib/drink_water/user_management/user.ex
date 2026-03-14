defmodule DrinkWater.UserManagement.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :first_name, :string
    field :last_name, :string
    field :birth_date, :date
    field :biological_sex, :integer
    field :weight, :decimal
    field :weight_unit, :integer
    field :height, :decimal
    field :height_unit, :integer

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :email,
      :first_name,
      :last_name,
      :birth_date,
      :biological_sex,
      :weight,
      :weight_unit,
      :height,
      :height_unit
    ])
    |> validate_required([
      :email,
      :first_name,
      :last_name,
      :birth_date,
      :biological_sex,
      :weight,
      :weight_unit,
      :height,
      :height_unit
    ])
  end
end
