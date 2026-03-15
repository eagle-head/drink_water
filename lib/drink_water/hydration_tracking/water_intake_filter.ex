defmodule DrinkWater.HydrationTracking.WaterIntakeFilter do
  use Ecto.Schema
  import Ecto.Changeset

  @default_size 10
  @max_size 50

  embedded_schema do
    field :start_date, :utc_datetime
    field :end_date, :utc_datetime
    field :min_volume, :integer
    field :max_volume, :integer
    field :cursor, :string
    field :size, :integer, default: @default_size
  end

  @optional_fields [:start_date, :end_date, :min_volume, :max_volume, :cursor, :size]

  def changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, @optional_fields)
    |> validate_required([:start_date, :end_date])
    |> validate_number(:size, greater_than_or_equal_to: 1, less_than_or_equal_to: @max_size)
    |> validate_number(:min_volume, greater_than_or_equal_to: 1, less_than_or_equal_to: 5000)
    |> validate_number(:max_volume, greater_than_or_equal_to: 1, less_than_or_equal_to: 5000)
    |> validate_date_range()
    |> validate_volume_range()
  end

  defp validate_date_range(changeset) do
    start_date = get_field(changeset, :start_date)
    end_date = get_field(changeset, :end_date)

    if start_date && end_date && DateTime.after?(start_date, end_date) do
      add_error(changeset, :end_date, "must be after or equal to start_date")
    else
      changeset
    end
  end

  defp validate_volume_range(changeset) do
    min_vol = get_field(changeset, :min_volume)
    max_vol = get_field(changeset, :max_volume)

    if min_vol && max_vol && min_vol > max_vol do
      add_error(changeset, :max_volume, "must be greater than or equal to min_volume")
    else
      changeset
    end
  end
end
