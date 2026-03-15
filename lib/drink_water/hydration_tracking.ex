defmodule DrinkWater.HydrationTracking do
  @moduledoc """
  The HydrationTracking context.
  """

  import Ecto.Query, warn: false
  import Ecto.Changeset, only: [apply_action: 2]
  alias DrinkWater.Repo

  alias DrinkWater.HydrationTracking.WaterIntake
  alias DrinkWater.HydrationTracking.WaterIntakeFilter

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
           |> apply_cursor(filter.cursor) do
      entries =
        query
        |> order_by(desc: :date_time_utc, desc: :id)
        |> limit(^(filter.size + 1))
        |> Repo.all()

      {page, next_cursor} = build_page(entries, filter.size)
      {:ok, %{entries: page, next_cursor: next_cursor}}
    end
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

  # Query composition

  defp apply_date_filter(query, %{start_date: start_date, end_date: end_date})
       when not is_nil(start_date) and not is_nil(end_date) do
    query
    |> where([w], w.date_time_utc >= ^start_date)
    |> where([w], w.date_time_utc <= ^end_date)
  end

  # start_date and end_date are required by WaterIntakeFilter, so this fallback
  # only fires if both are nil (which changeset validation prevents).
  defp apply_date_filter(query, _filter), do: query

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

  # Keyset pagination: cursor encodes (date_time_utc|id)
  defp apply_cursor(query, nil), do: {:ok, query}

  defp apply_cursor(query, cursor) do
    case decode_cursor(cursor) do
      {:ok, date_time, id} ->
        {:ok,
         where(
           query,
           [w],
           w.date_time_utc < ^date_time or
             (w.date_time_utc == ^date_time and w.id < ^id)
         )}

      :error ->
        {:error, :bad_request}
    end
  end

  defp build_page(entries, size) when length(entries) > size do
    page = Enum.take(entries, size)
    last = List.last(page)
    {page, encode_cursor(last.date_time_utc, last.id)}
  end

  defp build_page(entries, _size), do: {entries, nil}

  defp encode_cursor(date_time_utc, id) do
    "#{DateTime.to_iso8601(date_time_utc)}|#{id}"
    |> Base.url_encode64(padding: false)
  end

  defp decode_cursor(cursor) do
    with {:ok, decoded} <- Base.url_decode64(cursor, padding: false),
         [datetime_str, id_str] <- String.split(decoded, "|", parts: 2),
         {:ok, date_time, _offset} <- DateTime.from_iso8601(datetime_str),
         {id, ""} <- Integer.parse(id_str) do
      {:ok, date_time, id}
    else
      _ -> :error
    end
  end
end
