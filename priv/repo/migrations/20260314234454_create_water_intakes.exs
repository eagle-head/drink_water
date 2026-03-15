defmodule DrinkWater.Repo.Migrations.CreateWaterIntakes do
  use Ecto.Migration

  def change do
    create table(:water_intakes) do
      add :date_time_utc, :utc_datetime, null: false
      add :volume, :integer, null: false
      add :volume_unit, :string, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:water_intakes, [:user_id, :date_time_utc])
    create index(:water_intakes, [:user_id, :date_time_utc, :id], comment: "DESC search index")
  end
end
