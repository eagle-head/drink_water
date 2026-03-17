defmodule DrinkWater.HydrationTrackingDashboardTest do
  use DrinkWater.DataCase, async: true

  alias DrinkWater.HydrationTracking

  import DrinkWater.UserManagementFixtures
  import DrinkWater.HydrationTrackingFixtures

  describe "daily_progress/3" do
    test "returns zero progress when no intakes exist" do
      user = user_fixture()
      result = HydrationTracking.daily_progress(user.id, Date.utc_today(), 2000)

      assert result == %{total_ml: 0, goal: 2000, percentage: 0.0, intake_count: 0}
    end

    test "returns correct progress with intakes" do
      user = user_fixture()
      today = Date.utc_today()
      now = DateTime.utc_now()

      water_intake_fixture(user.id, %{date_time_utc: now, volume: 500})

      water_intake_fixture(user.id, %{
        date_time_utc: DateTime.add(now, -3600, :second),
        volume: 300
      })

      result = HydrationTracking.daily_progress(user.id, today, 2000)

      assert result == %{total_ml: 800, goal: 2000, percentage: 40.0, intake_count: 2}
    end

    test "caps percentage at 100 when goal is exceeded" do
      user = user_fixture()
      today = Date.utc_today()

      water_intake_fixture(user.id, %{date_time_utc: DateTime.utc_now(), volume: 2500})

      result = HydrationTracking.daily_progress(user.id, today, 2000)

      assert result.total_ml == 2500
      assert result.percentage == 100.0
    end

    test "excludes intakes from other days" do
      user = user_fixture()
      today = Date.utc_today()
      yesterday = Date.add(today, -1)

      water_intake_fixture(user.id, %{
        date_time_utc: DateTime.new!(yesterday, ~T[10:00:00], "Etc/UTC"),
        volume: 500
      })

      water_intake_fixture(user.id, %{date_time_utc: DateTime.utc_now(), volume: 300})

      result = HydrationTracking.daily_progress(user.id, today, 2000)
      assert result.total_ml == 300
      assert result.intake_count == 1
    end
  end

  describe "list_daily_intakes/2" do
    test "returns empty list when no intakes" do
      user = user_fixture()
      assert [] = HydrationTracking.list_daily_intakes(user.id, Date.utc_today())
    end

    test "returns intakes ordered by time desc" do
      user = user_fixture()
      now = DateTime.utc_now()
      earlier = DateTime.add(now, -3600, :second)

      water_intake_fixture(user.id, %{date_time_utc: earlier, volume: 200})
      water_intake_fixture(user.id, %{date_time_utc: now, volume: 500})

      intakes = HydrationTracking.list_daily_intakes(user.id, Date.utc_today())
      assert length(intakes) == 2
      assert hd(intakes).volume == 500
      assert List.last(intakes).volume == 200
    end

    test "excludes intakes from other days" do
      user = user_fixture()
      yesterday = Date.add(Date.utc_today(), -1)

      water_intake_fixture(user.id, %{
        date_time_utc: DateTime.new!(yesterday, ~T[10:00:00], "Etc/UTC"),
        volume: 300
      })

      water_intake_fixture(user.id, %{date_time_utc: DateTime.utc_now(), volume: 500})

      intakes = HydrationTracking.list_daily_intakes(user.id, Date.utc_today())
      assert length(intakes) == 1
      assert hd(intakes).volume == 500
    end
  end

  describe "delete_water_intake_by_id/2" do
    test "deletes an existing intake" do
      user = user_fixture()
      intake = water_intake_fixture(user.id)

      assert {:ok, deleted} = HydrationTracking.delete_water_intake_by_id(user.id, intake.id)
      assert deleted.id == intake.id

      assert {:error, :not_found, :water_intake} =
               HydrationTracking.get_water_intake(user.id, intake.id)
    end

    test "returns error for nonexistent intake" do
      user = user_fixture()

      assert {:error, :not_found, :water_intake} =
               HydrationTracking.delete_water_intake_by_id(user.id, 0)
    end

    test "returns error for intake belonging to another user" do
      user1 = user_fixture()
      user2 = user_fixture()
      intake = water_intake_fixture(user1.id)

      assert {:error, :not_found, :water_intake} =
               HydrationTracking.delete_water_intake_by_id(user2.id, intake.id)
    end
  end
end
