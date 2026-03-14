defmodule DrinkWaterWeb.AlarmSettingsController do
  use DrinkWaterWeb, :controller

  alias DrinkWater.UserManagement
  alias DrinkWater.UserManagement.AlarmSettings

  action_fallback DrinkWaterWeb.FallbackController

  def show(conn, %{"user_id" => user_id}) do
    with {:ok, _user} <- UserManagement.get_user(user_id),
         {:ok, alarm_settings} <- UserManagement.get_alarm_settings_by_user(user_id) do
      render(conn, :show, alarm_settings: alarm_settings)
    end
  end

  def create(conn, %{"user_id" => user_id, "alarm_settings" => alarm_settings_params}) do
    with {:ok, user} <- UserManagement.get_user(user_id),
         {:ok, %AlarmSettings{} = alarm_settings} <-
           UserManagement.create_alarm_settings(user, alarm_settings_params) do
      conn
      |> put_status(:created)
      |> render(:show, alarm_settings: alarm_settings)
    end
  end

  def update(conn, %{"user_id" => user_id, "alarm_settings" => alarm_settings_params}) do
    with {:ok, _user} <- UserManagement.get_user(user_id),
         {:ok, alarm_settings} <- UserManagement.get_alarm_settings_by_user(user_id),
         {:ok, %AlarmSettings{} = alarm_settings} <-
           UserManagement.update_alarm_settings(alarm_settings, alarm_settings_params) do
      render(conn, :show, alarm_settings: alarm_settings)
    end
  end

  def delete(conn, %{"user_id" => user_id}) do
    with {:ok, _user} <- UserManagement.get_user(user_id),
         {:ok, alarm_settings} <- UserManagement.get_alarm_settings_by_user(user_id),
         {:ok, %AlarmSettings{}} <- UserManagement.delete_alarm_settings(alarm_settings) do
      send_resp(conn, :no_content, "")
    end
  end
end
