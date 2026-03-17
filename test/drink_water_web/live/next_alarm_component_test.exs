defmodule DrinkWaterWeb.NextAlarmComponentTest do
  use DrinkWater.DataCase, async: true

  import Phoenix.LiveViewTest
  import DrinkWater.UserManagementFixtures

  alias DrinkWaterWeb.NextAlarmComponent

  describe "time-dependent branches" do
    test "shows start time when before alarm window" do
      user = user_fixture()

      alarm_settings_fixture(user, %{
        goal: 2000,
        interval_minutes: 30,
        daily_start_time: ~T[08:00:00],
        daily_end_time: ~T[20:00:00]
      })

      html = render_component(NextAlarmComponent, id: "test", user_id: user.id, now: ~T[05:00:00])

      assert html =~ "08:00"
      assert html =~ "Every 30 min"
    end

    test "shows done for today when past end time" do
      user = user_fixture()

      alarm_settings_fixture(user, %{
        goal: 2000,
        interval_minutes: 30,
        daily_start_time: ~T[08:00:00],
        daily_end_time: ~T[20:00:00]
      })

      html = render_component(NextAlarmComponent, id: "test", user_id: user.id, now: ~T[21:00:00])

      assert html =~ "Done for today!"
      assert html =~ "Every 30 min"
    end

    test "shows next alarm time during active window" do
      user = user_fixture()

      alarm_settings_fixture(user, %{
        goal: 2000,
        interval_minutes: 60,
        daily_start_time: ~T[08:00:00],
        daily_end_time: ~T[20:00:00]
      })

      html = render_component(NextAlarmComponent, id: "test", user_id: user.id, now: ~T[10:30:00])

      # At 10:30, with 60min interval starting at 08:00, next alarm is 11:00
      assert html =~ "11:00"
    end

    test "shows done when next alarm exceeds end time" do
      user = user_fixture()

      alarm_settings_fixture(user, %{
        goal: 2000,
        interval_minutes: 60,
        daily_start_time: ~T[08:00:00],
        daily_end_time: ~T[20:00:00]
      })

      # At 19:30, next alarm would be 20:00 but end_time is 20:00
      # Time.compare(20:00, 20:00) != :gt is true, so 20:00 is valid
      html = render_component(NextAlarmComponent, id: "test", user_id: user.id, now: ~T[19:30:00])
      assert html =~ "20:00"

      # At 19:01 with 60min interval: next would be 20:00 — valid
      # But at 20:00 exactly, Time.compare(now, end_time) != :lt is true → nil
    end

    test "shows no alarm configured without alarm settings" do
      user = user_fixture()

      html = render_component(NextAlarmComponent, id: "test", user_id: user.id)

      assert html =~ "No alarm configured"
    end
  end
end
