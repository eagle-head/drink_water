defmodule DrinkWater.UserManagement.User do
  use Ecto.Schema
  import Ecto.Changeset

  @min_age 13
  @max_age 99
  @name_format ~r/^[\p{L}](?:[\p{L}'\s-]*[\p{L}'])?$/u

  schema "users" do
    field :email, :string
    field :first_name, :string
    field :last_name, :string
    field :birth_date, :date
    field :biological_sex, Ecto.Enum, values: [:male, :female]
    field :weight, :decimal
    field :weight_unit, Ecto.Enum, values: [:kg]
    field :height, :decimal
    field :height_unit, Ecto.Enum, values: [:cm]

    has_one :alarm_settings, DrinkWater.UserManagement.AlarmSettings

    timestamps(type: :utc_datetime)
  end

  @required_fields [
    :email,
    :first_name,
    :last_name,
    :birth_date,
    :biological_sex,
    :weight,
    :weight_unit,
    :height,
    :height_unit
  ]

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must be a valid email address")
    |> validate_length(:email, max: 255)
    |> validate_length(:first_name, min: 2, max: 50)
    |> validate_length(:last_name, min: 2, max: 50)
    |> validate_format(:first_name, @name_format,
      message: "must contain only letters, spaces, hyphens, or apostrophes"
    )
    |> validate_format(:last_name, @name_format,
      message: "must contain only letters, spaces, hyphens, or apostrophes"
    )
    |> validate_number(:weight, greater_than_or_equal_to: 45, less_than_or_equal_to: 500)
    |> validate_number(:height, greater_than_or_equal_to: 50, less_than_or_equal_to: 250)
    |> validate_birth_date()
    |> unique_constraint(:email)
  end

  defp validate_birth_date(changeset) do
    validate_change(changeset, :birth_date, fn :birth_date, birth_date ->
      age = age_from_birth_date(birth_date)

      cond do
        age < @min_age -> [birth_date: "user must be at least #{@min_age} years old"]
        age > @max_age -> [birth_date: "user must be at most #{@max_age} years old"]
        true -> []
      end
    end)
  end

  defp age_from_birth_date(birth_date) do
    today = Date.utc_today()
    age = today.year - birth_date.year

    if {today.month, today.day} < {birth_date.month, birth_date.day} do
      age - 1
    else
      age
    end
  end
end
