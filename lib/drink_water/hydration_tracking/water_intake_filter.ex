defmodule DrinkWater.HydrationTracking.WaterIntakeFilter do
  use Ecto.Schema
  import Ecto.Changeset

  @default_size 10
  @max_size 50
  @allowed_sort_fields ~w(date_time_utc volume id)
  @allowed_sort_directions ~w(asc desc)

  embedded_schema do
    field :start_date, :utc_datetime
    field :end_date, :utc_datetime
    field :min_volume, :integer
    field :max_volume, :integer
    field :cursor, :string
    field :size, :integer, default: @default_size
    field :sort_field, :string, default: "date_time_utc"
    field :sort_direction, :string, default: "desc"
  end

  @cast_fields [
    :start_date,
    :end_date,
    :min_volume,
    :max_volume,
    :cursor,
    :size,
    :sort_field,
    :sort_direction
  ]

  def changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, @cast_fields)
    |> validate_required([:start_date, :end_date])
    |> validate_number(:size, greater_than_or_equal_to: 1, less_than_or_equal_to: @max_size)
    |> validate_number(:min_volume, greater_than_or_equal_to: 1, less_than_or_equal_to: 5000)
    |> validate_number(:max_volume, greater_than_or_equal_to: 1, less_than_or_equal_to: 5000)
    |> validate_length(:cursor, max: 200)
    |> validate_inclusion(:sort_field, @allowed_sort_fields)
    |> validate_inclusion(:sort_direction, @allowed_sort_directions)
    |> validate_date_range()
    |> validate_volume_range()
  end

  defp validate_date_range(changeset) do
    start_date = get_field(changeset, :start_date)
    end_date = get_field(changeset, :end_date)
    do_validate_date_range(changeset, start_date, end_date)
  end

  defp do_validate_date_range(changeset, start_date, end_date)
       when not is_nil(start_date) and not is_nil(end_date) do
    case DateTime.compare(start_date, end_date) do
      :gt -> add_error(changeset, :end_date, "must be after or equal to start_date")
      _ok -> changeset
    end
  end

  defp do_validate_date_range(changeset, _start_date, _end_date), do: changeset

  defp validate_volume_range(changeset) do
    min_vol = get_field(changeset, :min_volume)
    max_vol = get_field(changeset, :max_volume)
    do_validate_volume_range(changeset, min_vol, max_vol)
  end

  defp do_validate_volume_range(changeset, min_vol, max_vol)
       when not is_nil(min_vol) and not is_nil(max_vol) and min_vol > max_vol do
    add_error(changeset, :max_volume, "must be greater than or equal to min_volume")
  end

  defp do_validate_volume_range(changeset, _min_vol, _max_vol), do: changeset
end
