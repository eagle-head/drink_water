defmodule DrinkWater.UserManagement.AlarmSettings do
  use Ecto.Schema
  import Ecto.Changeset

  @min_allowed_time ~T[06:00:00]
  @max_allowed_time ~T[22:00:00]

  schema "alarm_settings" do
    field :goal, :integer
    field :interval_minutes, :integer
    field :daily_start_time, :time
    field :daily_end_time, :time

    belongs_to :user, DrinkWater.UserManagement.User

    timestamps(type: :utc_datetime)
  end

  @required_fields [:goal, :interval_minutes, :daily_start_time, :daily_end_time]

  @doc false
  def changeset(alarm_settings, attrs) do
    alarm_settings
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> validate_number(:goal, greater_than_or_equal_to: 50, less_than_or_equal_to: 10_000)
    |> validate_number(:interval_minutes,
      greater_than_or_equal_to: 15,
      less_than_or_equal_to: 240
    )
    |> validate_business_hours()
    |> validate_start_before_end()
    |> unique_constraint(:user_id)
  end

  defp validate_business_hours(changeset) do
    changeset
    |> validate_time_range(:daily_start_time)
    |> validate_time_range(:daily_end_time)
  end

  defp validate_time_range(changeset, field) do
    validate_change(changeset, field, fn ^field, time ->
      cond do
        Time.compare(time, @min_allowed_time) == :lt ->
          [{field, "must be at or after #{@min_allowed_time}"}]

        Time.compare(time, @max_allowed_time) == :gt ->
          [{field, "must be at or before #{@max_allowed_time}"}]

        true ->
          []
      end
    end)
  end

  defp validate_start_before_end(changeset) do
    start_time = get_field(changeset, :daily_start_time)
    end_time = get_field(changeset, :daily_end_time)

    if start_time && end_time && Time.compare(start_time, end_time) != :lt do
      add_error(changeset, :daily_end_time, "must be after start time")
    else
      changeset
    end
  end
end
