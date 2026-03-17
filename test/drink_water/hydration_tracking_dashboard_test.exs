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
end
