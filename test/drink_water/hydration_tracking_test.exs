defmodule DrinkWater.HydrationTrackingTest do
  use DrinkWater.DataCase

  alias DrinkWater.HydrationTracking

  describe "water_intakes" do
    alias DrinkWater.HydrationTracking.WaterIntake

    import DrinkWater.HydrationTrackingFixtures
    import DrinkWater.UserManagementFixtures

    @invalid_attrs %{date_time_utc: nil, volume: nil, volume_unit: nil}

    test "list_water_intakes/1 returns all water intakes for a user" do
      user = user_fixture()
      water_intake = water_intake_fixture(user.id)
      assert HydrationTracking.list_water_intakes(user.id) == [water_intake]
    end

    test "list_water_intakes/1 does not return other users intakes" do
      user1 = user_fixture()
      user2 = user_fixture()
      water_intake_fixture(user1.id)
      assert HydrationTracking.list_water_intakes(user2.id) == []
    end

    test "get_water_intake/2 returns water intake scoped by user" do
      user = user_fixture()
      water_intake = water_intake_fixture(user.id)
      assert {:ok, found} = HydrationTracking.get_water_intake(user.id, water_intake.id)
      assert found.id == water_intake.id
    end

    test "get_water_intake/2 returns error when not found" do
      user = user_fixture()
      assert {:error, :not_found} = HydrationTracking.get_water_intake(user.id, 0)
    end

    test "get_water_intake/2 returns error for another users intake" do
      user1 = user_fixture()
      user2 = user_fixture()
      water_intake = water_intake_fixture(user1.id)
      assert {:error, :not_found} = HydrationTracking.get_water_intake(user2.id, water_intake.id)
    end

    test "create_water_intake/2 with valid data creates a water intake" do
      user = user_fixture()

      valid_attrs = %{
        date_time_utc: ~U[2026-03-14 10:00:00Z],
        volume: 250,
        volume_unit: :ml
      }

      assert {:ok, %WaterIntake{} = water_intake} =
               HydrationTracking.create_water_intake(user.id, valid_attrs)

      assert water_intake.date_time_utc == ~U[2026-03-14 10:00:00Z]
      assert water_intake.volume == 250
      assert water_intake.volume_unit == :ml
      assert water_intake.user_id == user.id
    end

    test "create_water_intake/2 with invalid data returns error changeset" do
      user = user_fixture()

      assert {:error, %Ecto.Changeset{}} =
               HydrationTracking.create_water_intake(user.id, @invalid_attrs)
    end

    test "create_water_intake/2 rejects duplicate date_time_utc for same user" do
      user = user_fixture()
      water_intake_fixture(user.id, %{date_time_utc: ~U[2026-03-14 10:00:00Z]})

      attrs = %{date_time_utc: ~U[2026-03-14 10:00:00Z], volume: 500, volume_unit: :ml}
      assert {:error, changeset} = HydrationTracking.create_water_intake(user.id, attrs)
      assert changeset.errors[:user_id]
    end

    test "create_water_intake/2 rejects volume out of range" do
      user = user_fixture()
      attrs = %{date_time_utc: ~U[2026-03-14 10:00:00Z], volume: 5001, volume_unit: :ml}
      assert {:error, changeset} = HydrationTracking.create_water_intake(user.id, attrs)
      assert changeset.errors[:volume]
    end

    test "create_water_intake/2 rejects future date_time_utc" do
      user = user_fixture()
      future = DateTime.add(DateTime.utc_now(), 3600, :second)
      attrs = %{date_time_utc: future, volume: 250, volume_unit: :ml}
      assert {:error, changeset} = HydrationTracking.create_water_intake(user.id, attrs)
      assert changeset.errors[:date_time_utc]
    end

    test "create_water_intake/2 rejects invalid volume_unit" do
      user = user_fixture()
      attrs = %{date_time_utc: ~U[2026-03-14 10:00:00Z], volume: 250, volume_unit: "gallons"}
      assert {:error, changeset} = HydrationTracking.create_water_intake(user.id, attrs)
      assert changeset.errors[:volume_unit]
    end

    test "update_water_intake/2 with valid data updates the water intake" do
      water_intake = water_intake_fixture()

      update_attrs = %{
        date_time_utc: ~U[2026-03-14 14:00:00Z],
        volume: 500,
        volume_unit: :ml
      }

      assert {:ok, %WaterIntake{} = updated} =
               HydrationTracking.update_water_intake(water_intake, update_attrs)

      assert updated.date_time_utc == ~U[2026-03-14 14:00:00Z]
      assert updated.volume == 500
      assert updated.volume_unit == :ml
    end

    test "update_water_intake/2 with invalid data returns error changeset" do
      water_intake = water_intake_fixture()

      assert {:error, %Ecto.Changeset{}} =
               HydrationTracking.update_water_intake(water_intake, @invalid_attrs)

      assert {:ok, ^water_intake} =
               HydrationTracking.get_water_intake(water_intake.user_id, water_intake.id)
    end

    test "delete_water_intake/1 deletes the water intake" do
      user = user_fixture()
      water_intake = water_intake_fixture(user.id)
      assert {:ok, %WaterIntake{}} = HydrationTracking.delete_water_intake(water_intake)
      assert {:error, :not_found} = HydrationTracking.get_water_intake(user.id, water_intake.id)
    end

    test "water_intakes are deleted when user is deleted" do
      user = user_fixture()
      water_intake = water_intake_fixture(user.id)
      assert {:ok, _} = DrinkWater.UserManagement.delete_user(user)
      assert {:error, :not_found} = HydrationTracking.get_water_intake(user.id, water_intake.id)
    end
  end
end
