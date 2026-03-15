defmodule DrinkWater.HydrationTrackingTest do
  use DrinkWater.DataCase

  alias DrinkWater.HydrationTracking

  describe "water_intakes" do
    alias DrinkWater.HydrationTracking.WaterIntake

    import DrinkWater.HydrationTrackingFixtures
    import DrinkWater.UserManagementFixtures

    @invalid_attrs %{date_time_utc: nil, volume: nil, volume_unit: nil}

    @date_range %{
      "start_date" => "2026-03-01T00:00:00Z",
      "end_date" => "2026-03-31T23:59:59Z"
    }

    test "list_water_intakes/2 returns all water intakes for a user" do
      user = user_fixture()
      water_intake = water_intake_fixture(user.id)

      assert {:ok, %{entries: [^water_intake], next_cursor: nil}} =
               HydrationTracking.list_water_intakes(user.id, @date_range)
    end

    test "list_water_intakes/2 does not return other users intakes" do
      user1 = user_fixture()
      user2 = user_fixture()
      water_intake_fixture(user1.id)

      assert {:ok, %{entries: [], next_cursor: nil}} =
               HydrationTracking.list_water_intakes(user2.id, @date_range)
    end

    test "list_water_intakes/2 filters by date range" do
      user = user_fixture()
      water_intake_fixture(user.id, %{date_time_utc: ~U[2026-03-05 10:00:00Z]})
      water_intake_fixture(user.id, %{date_time_utc: ~U[2026-03-10 10:00:00Z]})

      params = %{"start_date" => "2026-03-08T00:00:00Z", "end_date" => "2026-03-14T23:59:59Z"}
      assert {:ok, %{entries: entries}} = HydrationTracking.list_water_intakes(user.id, params)
      assert length(entries) == 1
      assert hd(entries).date_time_utc == ~U[2026-03-10 10:00:00Z]
    end

    test "list_water_intakes/2 filters by volume range" do
      user = user_fixture()
      water_intake_fixture(user.id, %{date_time_utc: ~U[2026-03-14 10:00:00Z], volume: 100})
      water_intake_fixture(user.id, %{date_time_utc: ~U[2026-03-14 11:00:00Z], volume: 500})

      params = Map.merge(@date_range, %{"min_volume" => "200", "max_volume" => "600"})
      assert {:ok, %{entries: entries}} = HydrationTracking.list_water_intakes(user.id, params)
      assert length(entries) == 1
      assert hd(entries).volume == 500
    end

    test "list_water_intakes/2 filters by min_volume only" do
      user = user_fixture()
      water_intake_fixture(user.id, %{date_time_utc: ~U[2026-03-14 10:00:00Z], volume: 100})
      water_intake_fixture(user.id, %{date_time_utc: ~U[2026-03-14 11:00:00Z], volume: 500})

      params = Map.merge(@date_range, %{"min_volume" => "200"})
      assert {:ok, %{entries: entries}} = HydrationTracking.list_water_intakes(user.id, params)
      assert length(entries) == 1
      assert hd(entries).volume == 500
    end

    test "list_water_intakes/2 filters by max_volume only" do
      user = user_fixture()
      water_intake_fixture(user.id, %{date_time_utc: ~U[2026-03-14 10:00:00Z], volume: 100})
      water_intake_fixture(user.id, %{date_time_utc: ~U[2026-03-14 11:00:00Z], volume: 500})

      params = Map.merge(@date_range, %{"max_volume" => "200"})
      assert {:ok, %{entries: entries}} = HydrationTracking.list_water_intakes(user.id, params)
      assert length(entries) == 1
      assert hd(entries).volume == 100
    end

    test "list_water_intakes/2 paginates with cursor" do
      user = user_fixture()

      for i <- 1..3 do
        water_intake_fixture(user.id, %{
          date_time_utc: DateTime.add(~U[2026-03-10 10:00:00Z], i * 3600, :second)
        })
      end

      params = Map.merge(@date_range, %{"size" => "2"})

      assert {:ok, %{entries: page1, next_cursor: cursor}} =
               HydrationTracking.list_water_intakes(user.id, params)

      assert length(page1) == 2
      assert cursor != nil

      params2 = Map.merge(@date_range, %{"size" => "2", "cursor" => cursor})

      assert {:ok, %{entries: page2, next_cursor: nil}} =
               HydrationTracking.list_water_intakes(user.id, params2)

      assert length(page2) == 1
    end

    test "list_water_intakes/2 returns error when max_volume < min_volume" do
      user = user_fixture()
      params = Map.merge(@date_range, %{"min_volume" => "500", "max_volume" => "100"})
      assert {:error, changeset} = HydrationTracking.list_water_intakes(user.id, params)
      assert changeset.errors[:max_volume]
    end

    test "list_water_intakes/2 returns error for invalid filter params" do
      user = user_fixture()
      params = %{"start_date" => "2026-03-31T00:00:00Z", "end_date" => "2026-03-01T00:00:00Z"}
      assert {:error, %Ecto.Changeset{}} = HydrationTracking.list_water_intakes(user.id, params)
    end

    test "list_water_intakes/2 returns error when required dates are missing" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{}} = HydrationTracking.list_water_intakes(user.id, %{})
    end

    test "list_water_intakes/2 returns error for invalid cursor" do
      user = user_fixture()
      params = Map.merge(@date_range, %{"cursor" => "invalid-cursor"})
      assert {:error, :bad_request} = HydrationTracking.list_water_intakes(user.id, params)
    end

    test "list_water_intakes/2 paginates correctly with close timestamps (id tie-breaker)" do
      user = user_fixture()

      for i <- 1..3 do
        water_intake_fixture(user.id, %{
          date_time_utc: DateTime.add(~U[2026-03-10 10:00:00Z], i, :second),
          volume: i * 100
        })
      end

      params = Map.merge(@date_range, %{"size" => "2"})

      assert {:ok, %{entries: page1, next_cursor: cursor}} =
               HydrationTracking.list_water_intakes(user.id, params)

      assert length(page1) == 2
      assert cursor != nil

      params2 = Map.merge(@date_range, %{"size" => "2", "cursor" => cursor})

      assert {:ok, %{entries: page2, next_cursor: nil}} =
               HydrationTracking.list_water_intakes(user.id, params2)

      assert length(page2) == 1

      all_ids = Enum.map(page1 ++ page2, & &1.id)
      assert length(Enum.uniq(all_ids)) == 3
    end

    test "get_water_intake/2 returns water intake scoped by user" do
      user = user_fixture()
      water_intake = water_intake_fixture(user.id)
      assert {:ok, found} = HydrationTracking.get_water_intake(user.id, water_intake.id)
      assert found.id == water_intake.id
    end

    test "get_water_intake/2 returns error when not found" do
      user = user_fixture()
      assert {:error, :not_found, :water_intake} = HydrationTracking.get_water_intake(user.id, 0)
    end

    test "get_water_intake/2 returns error for another users intake" do
      user1 = user_fixture()
      user2 = user_fixture()
      water_intake = water_intake_fixture(user1.id)

      assert {:error, :not_found, :water_intake} =
               HydrationTracking.get_water_intake(user2.id, water_intake.id)
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

    test "create_water_intake/2 returns {:error, :conflict, :water_intake} for duplicate datetime" do
      user = user_fixture()
      datetime = ~U[2024-08-14 10:00:00Z]

      {:ok, _} =
        HydrationTracking.create_water_intake(user.id, %{
          date_time_utc: datetime,
          volume: 250,
          volume_unit: :ml
        })

      assert {:error, :conflict, :water_intake} =
               HydrationTracking.create_water_intake(user.id, %{
                 date_time_utc: datetime,
                 volume: 300,
                 volume_unit: :ml
               })
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

    test "update_water_intake/2 returns {:error, :conflict, :water_intake} for duplicate datetime" do
      user = user_fixture()
      datetime1 = ~U[2024-08-14 10:00:00Z]
      datetime2 = ~U[2024-08-14 11:00:00Z]

      {:ok, _intake1} =
        HydrationTracking.create_water_intake(user.id, %{
          date_time_utc: datetime1,
          volume: 250,
          volume_unit: :ml
        })

      {:ok, intake2} =
        HydrationTracking.create_water_intake(user.id, %{
          date_time_utc: datetime2,
          volume: 300,
          volume_unit: :ml
        })

      assert {:error, :conflict, :water_intake} =
               HydrationTracking.update_water_intake(intake2, %{date_time_utc: datetime1})
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

      assert {:error, :not_found, :water_intake} =
               HydrationTracking.get_water_intake(user.id, water_intake.id)
    end

    test "water_intakes are deleted when user is deleted" do
      user = user_fixture()
      water_intake = water_intake_fixture(user.id)
      assert {:ok, _} = DrinkWater.UserManagement.delete_user(user)

      assert {:error, :not_found, :water_intake} =
               HydrationTracking.get_water_intake(user.id, water_intake.id)
    end
  end
end
