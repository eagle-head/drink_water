defmodule DrinkWater.HydrationTracking.WaterIntake do
  use Ecto.Schema
  import Ecto.Changeset

  schema "water_intakes" do
    field :date_time_utc, :utc_datetime
    field :volume, :integer
    field :volume_unit, Ecto.Enum, values: [:ml]
    field :user_id, :id

    timestamps(type: :utc_datetime)
  end

  @required_fields [:date_time_utc, :volume, :volume_unit]

  @doc false
  def changeset(water_intake, attrs) do
    water_intake
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> validate_number(:volume, greater_than_or_equal_to: 1, less_than_or_equal_to: 5000)
    |> validate_not_future()
    |> unique_constraint([:user_id, :date_time_utc])
  end

  defp validate_not_future(changeset) do
    validate_change(changeset, :date_time_utc, fn :date_time_utc, date_time_utc ->
      if DateTime.after?(date_time_utc, DateTime.utc_now()) do
        [date_time_utc: "must not be in the future"]
      else
        []
      end
    end)
  end
end
