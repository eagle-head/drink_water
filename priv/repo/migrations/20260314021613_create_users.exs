defmodule DrinkWater.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :string
      add :first_name, :string
      add :last_name, :string
      add :birth_date, :date
      add :biological_sex, :integer
      add :weight, :decimal
      add :weight_unit, :integer
      add :height, :decimal
      add :height_unit, :integer

      timestamps(type: :utc_datetime)
    end
  end
end
