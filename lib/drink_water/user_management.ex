defmodule DrinkWater.UserManagement do
  @moduledoc """
  The UserManagement context.
  """

  import Ecto.Query, warn: false
  alias DrinkWater.Repo

  alias DrinkWater.UserManagement.User

  @doc """
  Gets a single user.

  Returns `{:ok, %User{}}` if the user exists, `{:error, :not_found, :user}` otherwise.

  ## Examples

      iex> get_user(123)
      {:ok, %User{}}

      iex> get_user(456)
      {:error, :not_found, :user}

  """
  def get_user(id) when is_integer(id) do
    case Repo.get(User, id) do
      nil -> {:error, :not_found, :user}
      user -> {:ok, user}
    end
  end

  def get_user(id) when is_binary(id) do
    case Integer.parse(id) do
      {int_id, ""} -> get_user(int_id)
      _ -> {:error, :not_found, :user}
    end
  end

  def get_user(_), do: {:error, :not_found, :user}

  @doc """
  Creates a user.

  ## Examples

      iex> create_user(%{field: value})
      {:ok, %User{}}

      iex> create_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
    |> maybe_conflict(:user, :email)
  end

  @doc """
  Updates a user.

  ## Examples

      iex> update_user(user, %{field: new_value})
      {:ok, %User{}}

      iex> update_user(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user.

  ## Examples

      iex> delete_user(user)
      {:ok, %User{}}

      iex> delete_user(user)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Deletes a user by ID. Idempotent — returns `:ok` whether the user
  existed or not. Accepts integer or string ID.

  Always returns `:ok` by design: the API must not reveal whether a
  given user ID exists (prevents user enumeration). Observability
  comes from structured logging and telemetry, not HTTP status codes.
  Related records (alarm_settings, water_intakes) are cascade-deleted
  by the database via ON DELETE CASCADE constraints.
  """
  def delete_user_by_id(id) when is_integer(id) do
    User
    |> where(id: ^id)
    |> Repo.delete_all()

    :ok
  end

  def delete_user_by_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int_id, ""} -> delete_user_by_id(int_id)
      _ -> :ok
    end
  end

  def delete_user_by_id(_), do: :ok

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user(%User{} = user, attrs \\ %{}) do
    User.changeset(user, attrs)
  end

  alias DrinkWater.UserManagement.AlarmSettings

  @doc """
  Gets the alarm settings for a user.

  Returns `{:ok, %AlarmSettings{}}` or `{:error, :not_found, :alarm_settings}`.
  """
  def get_alarm_settings_by_user(user_id) do
    case Repo.get_by(AlarmSettings, user_id: user_id) do
      nil -> {:error, :not_found, :alarm_settings}
      alarm_settings -> {:ok, alarm_settings}
    end
  end

  @doc """
  Creates alarm settings for a user.

  The `user_id` is set via association, not through user input.
  """
  def create_alarm_settings(%User{} = user, attrs) do
    user
    |> Ecto.build_assoc(:alarm_settings)
    |> AlarmSettings.changeset(attrs)
    |> Repo.insert()
    |> maybe_conflict(:alarm_settings, :user_id)
  end

  @doc """
  Updates alarm settings.
  """
  def update_alarm_settings(%AlarmSettings{} = alarm_settings, attrs) do
    case alarm_settings
         |> AlarmSettings.changeset(attrs)
         |> Repo.update() do
      {:ok, updated} ->
        Phoenix.PubSub.broadcast(
          DrinkWater.PubSub,
          "user:#{updated.user_id}",
          :alarm_settings_updated
        )

        {:ok, updated}

      error ->
        error
    end
  end

  @doc """
  Deletes alarm settings.
  """
  def delete_alarm_settings(%AlarmSettings{} = alarm_settings) do
    Repo.delete(alarm_settings)
  end

  defp maybe_conflict({:error, %Ecto.Changeset{} = changeset}, resource, field) do
    if has_unique_constraint_error?(changeset, field) do
      {:error, :conflict, resource}
    else
      {:error, changeset}
    end
  end

  defp maybe_conflict(result, _resource, _field), do: result

  defp has_unique_constraint_error?(changeset, field) do
    Enum.any?(changeset.errors, fn
      {^field, {_msg, opts}} -> opts[:constraint] == :unique
      _ -> false
    end)
  end
end
