defmodule DrinkWater.Repo.Migrations.CreateAlarmSettings do
  use Ecto.Migration

  def change do
    create table(:alarm_settings) do
      add :goal, :integer, null: false
      add :interval_minutes, :integer, null: false
      add :daily_start_time, :time, null: false
      add :daily_end_time, :time, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:alarm_settings, [:user_id])
  end
end
