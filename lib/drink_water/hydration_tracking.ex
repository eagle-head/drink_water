defmodule DrinkWater.HydrationTracking do
  @moduledoc """
  The HydrationTracking context.
  """

  import Ecto.Query, warn: false
  import Ecto.Changeset, only: [apply_action: 2]
  alias DrinkWater.Repo

  alias DrinkWater.HydrationTracking.WaterIntake
  alias DrinkWater.HydrationTracking.WaterIntakeFilter

  @sort_field_atoms %{
    "date_time_utc" => :date_time_utc,
    "volume" => :volume,
    "id" => :id
  }

  @sort_dir_atoms %{
    "asc" => :asc,
    "desc" => :desc
  }

  @doc """
  Lists water intakes for a user with filtering and cursor-based pagination.

  Returns `{:ok, %{entries: [...], next_cursor: cursor | nil}}` or
  `{:error, %Ecto.Changeset{}}` if filter params are invalid.
  """
  def list_water_intakes(user_id, params \\ %{}) do
    with {:ok, filter} <- WaterIntakeFilter.changeset(params) |> apply_action(:validate),
         {:ok, query} <-
           WaterIntake
           |> where(user_id: ^user_id)
           |> apply_date_filter(filter)
           |> apply_volume_filter(filter)
           |> apply_cursor(filter) do
      entries =
        query
        |> apply_sort(filter)
        |> limit(^(filter.size + 1))
        |> Repo.all()

      {page, next_cursor} = build_page(entries, filter)
      {:ok, %{entries: page, next_cursor: next_cursor}}
    end
  end

  @doc """
  Returns daily hydration progress for a user.

  The `goal` parameter comes from AlarmSettings.goal (integer, in ml).
  """
  def daily_progress(user_id, %Date{} = date, goal) when is_integer(goal) and goal > 0 do
    start_of_day = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    end_of_day = DateTime.new!(Date.add(date, 1), ~T[00:00:00], "Etc/UTC")

    {total_ml, intake_count} =
      WaterIntake
      |> where(user_id: ^user_id)
      |> where([w], w.date_time_utc >= ^start_of_day and w.date_time_utc < ^end_of_day)
      |> select([w], {coalesce(sum(w.volume), 0), count(w.id)})
      |> Repo.one()

    percentage = min(total_ml / goal * 100.0, 100.0) |> Float.round(1)

    %{total_ml: total_ml, goal: goal, percentage: percentage, intake_count: intake_count}
  end

  @doc """
  Returns all water intakes for a user on a given date, ordered by time desc.
  No pagination — returns the full list for dashboard display.
  """
  def list_daily_intakes(user_id, %Date{} = date) do
    start_of_day = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    end_of_day = DateTime.new!(Date.add(date, 1), ~T[00:00:00], "Etc/UTC")

    WaterIntake
    |> where(user_id: ^user_id)
    |> where([w], w.date_time_utc >= ^start_of_day and w.date_time_utc < ^end_of_day)
    |> order_by([w], desc: w.date_time_utc)
    |> Repo.all()
  end

  @doc """
  Gets a single water intake scoped by user.

  Returns `{:ok, %WaterIntake{}}` or `{:error, :not_found, :water_intake}`.
  """
  def get_water_intake(user_id, id) do
    case Repo.get_by(WaterIntake, id: id, user_id: user_id) do
      nil -> {:error, :not_found, :water_intake}
      water_intake -> {:ok, water_intake}
    end
  end

  @doc """
  Creates a water intake for a user.

  The `user_id` is set programmatically, not through user input.
  """
  def create_water_intake(user_id, attrs) do
    result =
      %WaterIntake{user_id: user_id}
      |> WaterIntake.changeset(attrs)
      |> Repo.insert()
      |> maybe_conflict(:water_intake)

    case result do
      {:ok, intake} ->
        broadcast_event(intake.user_id, :intake_created)
        {:ok, intake}

      error ->
        error
    end
  end

  @doc """
  Updates a water intake.
  """
  def update_water_intake(%WaterIntake{} = water_intake, attrs) do
    water_intake
    |> WaterIntake.changeset(attrs)
    |> Repo.update()
    |> maybe_conflict(:water_intake)
  end

  @doc """
  Deletes a water intake.
  """
  def delete_water_intake(%WaterIntake{} = water_intake) do
    case Repo.delete(water_intake) do
      {:ok, deleted} ->
        broadcast_event(deleted.user_id, :intake_deleted)
        {:ok, deleted}

      error ->
        error
    end
  end

  @doc """
  Deletes a water intake by user_id and intake id.
  Independent implementation — does not delegate to delete_water_intake/1
  to avoid double broadcasts.
  """
  def delete_water_intake_by_id(user_id, intake_id) do
    with {:ok, intake} <- get_water_intake(user_id, intake_id),
         {:ok, deleted} <- Repo.delete(intake) do
      broadcast_event(user_id, :intake_deleted)
      {:ok, deleted}
    end
  end

  defp broadcast_event(user_id, event) do
    Phoenix.PubSub.broadcast(DrinkWater.PubSub, "user:#{user_id}", event)
  end

  defp maybe_conflict({:error, %Ecto.Changeset{} = changeset}, resource) do
    if has_unique_constraint_error?(changeset) do
      {:error, :conflict, resource}
    else
      {:error, changeset}
    end
  end

  defp maybe_conflict(result, _resource), do: result

  defp has_unique_constraint_error?(changeset) do
    Enum.any?(changeset.errors, fn
      {_field, {_msg, opts}} -> opts[:constraint] == :unique
    end)
  end

  # Query composition

  defp apply_sort(query, %{sort_field: field, sort_direction: dir}) do
    sort_field = Map.fetch!(@sort_field_atoms, field)
    sort_dir = Map.fetch!(@sort_dir_atoms, dir)

    order_by(query, [w], [{^sort_dir, field(w, ^sort_field)}, {^sort_dir, w.id}])
  end

  defp apply_date_filter(query, %{start_date: start_date, end_date: end_date}) do
    query
    |> where([w], w.date_time_utc >= ^start_date)
    |> where([w], w.date_time_utc <= ^end_date)
  end

  defp apply_volume_filter(query, %{min_volume: min, max_volume: max})
       when not is_nil(min) and not is_nil(max) do
    query
    |> where([w], w.volume >= ^min)
    |> where([w], w.volume <= ^max)
  end

  defp apply_volume_filter(query, %{min_volume: min}) when not is_nil(min) do
    where(query, [w], w.volume >= ^min)
  end

  defp apply_volume_filter(query, %{max_volume: max}) when not is_nil(max) do
    where(query, [w], w.volume <= ^max)
  end

  defp apply_volume_filter(query, _filter), do: query

  # Keyset pagination: cursor encodes (sort_field:sort_value|id).
  # Returns {:ok, query} or {:error, :bad_request} — the only query
  # composition function that can fail (invalid/mismatched cursor).
  defp apply_cursor(query, %{cursor: nil}), do: {:ok, query}

  defp apply_cursor(query, %{cursor: cursor, sort_field: field, sort_direction: dir}) do
    sort_field = Map.fetch!(@sort_field_atoms, field)

    case decode_cursor(cursor) do
      {:ok, cursor_value, cursor_id, cursor_field} when cursor_field == field ->
        filtered =
          if dir == "desc" do
            where(
              query,
              [w],
              field(w, ^sort_field) < ^cursor_value or
                (field(w, ^sort_field) == ^cursor_value and w.id < ^cursor_id)
            )
          else
            where(
              query,
              [w],
              field(w, ^sort_field) > ^cursor_value or
                (field(w, ^sort_field) == ^cursor_value and w.id > ^cursor_id)
            )
          end

        {:ok, filtered}

      {:ok, _cursor_value, _cursor_id, _wrong_field} ->
        {:error, :bad_request}

      :error ->
        {:error, :bad_request}
    end
  end

  defp build_page(entries, %{size: size, sort_field: field} = _filter) do
    if length(entries) > size do
      page = Enum.take(entries, size)
      last = List.last(page)
      sort_value = Map.get(last, Map.fetch!(@sort_field_atoms, field))
      {page, encode_cursor(sort_value, last.id, field)}
    else
      {entries, nil}
    end
  end

  defp encode_cursor(%DateTime{} = value, id, sort_field) do
    "#{sort_field}:#{DateTime.to_iso8601(value)}|#{id}"
    |> Base.url_encode64(padding: false)
  end

  defp encode_cursor(value, id, sort_field) do
    "#{sort_field}:#{value}|#{id}"
    |> Base.url_encode64(padding: false)
  end

  defp decode_cursor(cursor) do
    with {:ok, decoded} <- Base.url_decode64(cursor, padding: false),
         [value_str, id_str] <- String.split(decoded, "|", parts: 2),
         {id, ""} <- Integer.parse(id_str),
         {cursor_field, value_str} <- split_field_value(value_str) do
      cursor_value = parse_cursor_value(value_str)

      if cursor_value do
        {:ok, cursor_value, id, cursor_field}
      else
        :error
      end
    else
      _ -> :error
    end
  end

  defp split_field_value(str) do
    case String.split(str, ":", parts: 2) do
      [field, value] -> {field, value}
      _ -> :error
    end
  end

  defp parse_cursor_value(value_str) do
    case DateTime.from_iso8601(value_str) do
      {:ok, datetime, _offset} ->
        datetime

      _ ->
        case Integer.parse(value_str) do
          {int, ""} -> int
          _ -> nil
        end
    end
  end
end
