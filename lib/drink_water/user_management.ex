defmodule DrinkWater.UserManagement do
  @moduledoc """
  The UserManagement context.
  """

  import Ecto.Query, warn: false
  alias DrinkWater.Repo

  alias DrinkWater.UserManagement.User

  @doc """
  Returns the list of users.

  ## Examples

      iex> list_users()
      [%User{}, ...]

  """
  def list_users do
    Repo.all(User)
  end

  @doc """
  Gets a single user.

  Returns `{:ok, %User{}}` if the user exists, `{:error, :not_found}` otherwise.

  ## Examples

      iex> get_user(123)
      {:ok, %User{}}

      iex> get_user(456)
      {:error, :not_found}

  """
  def get_user(id) do
    case Repo.get(User, id) do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end

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

  Returns `{:ok, %AlarmSettings{}}` or `{:error, :not_found}`.
  """
  def get_alarm_settings_by_user(user_id) do
    case Repo.get_by(AlarmSettings, user_id: user_id) do
      nil -> {:error, :not_found}
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
  end

  @doc """
  Updates alarm settings.
  """
  def update_alarm_settings(%AlarmSettings{} = alarm_settings, attrs) do
    alarm_settings
    |> AlarmSettings.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes alarm settings.
  """
  def delete_alarm_settings(%AlarmSettings{} = alarm_settings) do
    Repo.delete(alarm_settings)
  end
end
