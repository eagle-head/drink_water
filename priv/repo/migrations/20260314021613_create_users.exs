defmodule DrinkWater.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :string, null: false
      add :first_name, :string, null: false
      add :last_name, :string, null: false
      add :birth_date, :date, null: false
      add :biological_sex, :string, null: false
      add :weight, :decimal, null: false
      add :weight_unit, :string, null: false
      add :height, :decimal, null: false
      add :height_unit, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
  end
end
