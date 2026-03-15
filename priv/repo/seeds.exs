# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# It is idempotent: truncates tables and resets ID sequences before inserting.

alias DrinkWater.Repo
alias DrinkWater.UserManagement.User
alias DrinkWater.UserManagement.AlarmSettings
alias DrinkWater.HydrationTracking.WaterIntake

# Clean slate — TRUNCATE resets ID sequences so IDs always start from 1
Repo.query!("TRUNCATE users, alarm_settings, water_intakes RESTART IDENTITY CASCADE")

# --- Users ---

{:ok, john} =
  %User{}
  |> User.changeset(%{
    email: "john.doe@test.com",
    first_name: "John",
    last_name: "Doe",
    birth_date: "1990-01-01",
    biological_sex: :male,
    weight: 70.5,
    weight_unit: :kg,
    height: 175,
    height_unit: :cm
  })
  |> Repo.insert()

{:ok, jane} =
  %User{}
  |> User.changeset(%{
    email: "jane.smith@test.com",
    first_name: "Jane",
    last_name: "Smith",
    birth_date: "1985-05-15",
    biological_sex: :female,
    weight: 60.0,
    weight_unit: :kg,
    height: 165,
    height_unit: :cm
  })
  |> Repo.insert()

{:ok, alex} =
  %User{}
  |> User.changeset(%{
    email: "alex.jones@test.com",
    first_name: "Alex",
    last_name: "Jones",
    birth_date: "1992-10-10",
    biological_sex: :male,
    weight: 80.0,
    weight_unit: :kg,
    height: 180,
    height_unit: :cm
  })
  |> Repo.insert()

# --- Alarm Settings ---

john
|> Ecto.build_assoc(:alarm_settings)
|> AlarmSettings.changeset(%{
  goal: 2000,
  interval_minutes: 60,
  daily_start_time: "08:00:00",
  daily_end_time: "22:00:00"
})
|> Repo.insert!()

jane
|> Ecto.build_assoc(:alarm_settings)
|> AlarmSettings.changeset(%{
  goal: 1500,
  interval_minutes: 45,
  daily_start_time: "07:00:00",
  daily_end_time: "21:00:00"
})
|> Repo.insert!()

alex
|> Ecto.build_assoc(:alarm_settings)
|> AlarmSettings.changeset(%{
  goal: 1750,
  interval_minutes: 30,
  daily_start_time: "09:00:00",
  daily_end_time: "20:00:00"
})
|> Repo.insert!()

# --- Water Intakes ---

john_intakes = [
  %{date_time_utc: "2024-08-14T10:00:00Z", volume: 250, volume_unit: :ml},
  %{date_time_utc: "2024-08-14T11:00:00Z", volume: 300, volume_unit: :ml},
  %{date_time_utc: "2024-08-14T12:00:00Z", volume: 200, volume_unit: :ml},
  %{date_time_utc: "2024-08-14T13:00:00Z", volume: 400, volume_unit: :ml},
  %{date_time_utc: "2024-08-14T14:00:00Z", volume: 500, volume_unit: :ml}
]

jane_intakes = [
  %{date_time_utc: "2024-08-14T10:30:00Z", volume: 300, volume_unit: :ml},
  %{date_time_utc: "2024-08-14T11:30:00Z", volume: 350, volume_unit: :ml},
  %{date_time_utc: "2024-08-14T12:30:00Z", volume: 250, volume_unit: :ml},
  %{date_time_utc: "2024-08-14T13:30:00Z", volume: 450, volume_unit: :ml},
  %{date_time_utc: "2024-08-14T14:30:00Z", volume: 500, volume_unit: :ml}
]

alex_intakes = [
  %{date_time_utc: "2024-08-14T09:30:00Z", volume: 500, volume_unit: :ml},
  %{date_time_utc: "2024-08-14T10:30:00Z", volume: 250, volume_unit: :ml},
  %{date_time_utc: "2024-08-14T11:30:00Z", volume: 350, volume_unit: :ml},
  %{date_time_utc: "2024-08-14T12:30:00Z", volume: 450, volume_unit: :ml},
  %{date_time_utc: "2024-08-14T13:30:00Z", volume: 550, volume_unit: :ml}
]

for {user, intakes} <- [{john, john_intakes}, {jane, jane_intakes}, {alex, alex_intakes}],
    attrs <- intakes do
  %WaterIntake{user_id: user.id}
  |> WaterIntake.changeset(attrs)
  |> Repo.insert!()
end

IO.puts("Seeds inserted: 3 users, 3 alarm settings, 15 water intakes")
