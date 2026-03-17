defmodule DrinkWaterWeb.DashboardLiveTest do
  # async: false because setup modifies Application env (global state)
  use DrinkWaterWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import DrinkWater.UserManagementFixtures
  import DrinkWater.HydrationTrackingFixtures

  setup do
    user = user_fixture(%{first_name: "John", last_name: "Doe"})

    Application.put_env(:drink_water, :dashboard_user_id, user.id)
    on_exit(fn -> Application.delete_env(:drink_water, :dashboard_user_id) end)

    %{user: user}
  end

  describe "dashboard page" do
    setup %{user: user} do
      alarm_settings_fixture(user, %{goal: 2000, interval_minutes: 60})
      :ok
    end

    test "renders dashboard with user name", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/dashboard")

      assert html =~ "Hydration Dashboard"
      assert html =~ "John Doe"
    end

    test "redirects when user not found", %{conn: conn} do
      Application.put_env(:drink_water, :dashboard_user_id, 999_999)

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, "/dashboard")
    end

    test "ignores unknown PubSub events", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard")

      send(view.pid, :some_unknown_event)

      html = render(view)
      assert html =~ "Hydration Dashboard"
    end
  end

  describe "without alarm settings" do
    test "shows default goal of 2000ml", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/dashboard")

      assert html =~ "2000ml"
    end

    test "shows no alarm configured for next alarm", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/dashboard")

      assert html =~ "No alarm configured"
    end

    test "shows no alarm configured for alarm settings", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/dashboard")

      # Both NextAlarm and AlarmSettings cards show "No alarm configured"
      assert html
             |> String.split("No alarm configured")
             |> length() >= 3
    end
  end

  describe "daily progress" do
    setup %{user: user} do
      alarm_settings_fixture(user, %{goal: 2000, interval_minutes: 60})
      :ok
    end

    test "shows 0ml when no intakes logged today", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/dashboard")

      assert html =~ "0ml"
      assert html =~ "2000ml"
      assert html =~ "0%"
    end

    test "shows current progress with intakes", %{conn: conn, user: user} do
      water_intake_fixture(user.id, %{date_time_utc: DateTime.utc_now(), volume: 750})

      {:ok, _view, html} = live(conn, "/dashboard")

      assert html =~ "750ml"
      assert html =~ "2000ml"
    end
  end

  describe "today's history" do
    setup %{user: user} do
      alarm_settings_fixture(user, %{goal: 2000, interval_minutes: 60})
      :ok
    end

    test "shows today's intakes", %{conn: conn, user: user} do
      water_intake_fixture(user.id, %{date_time_utc: DateTime.utc_now(), volume: 250})

      {:ok, _view, html} = live(conn, "/dashboard")

      assert html =~ "250"
    end

    test "shows empty state when no intakes", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/dashboard")

      assert html =~ "No water logged today"
    end

    test "deleting an intake removes it from the list", %{conn: conn, user: user} do
      intake = water_intake_fixture(user.id, %{date_time_utc: DateTime.utc_now(), volume: 350})

      {:ok, view, _html} = live(conn, "/dashboard")

      view
      |> element("[data-intake-id=\"#{intake.id}\"] button[phx-click=\"delete\"]")
      |> render_click()

      refute render(view) =~ "350"
    end

    test "shows flash when deleting an already-removed intake", %{conn: conn, user: user} do
      intake = water_intake_fixture(user.id, %{date_time_utc: DateTime.utc_now(), volume: 400})

      {:ok, view, _html} = live(conn, "/dashboard")

      # Delete directly from DB without broadcast — UI still shows the button
      DrinkWater.Repo.delete!(intake)

      view
      |> element("[data-intake-id=\"#{intake.id}\"] button[phx-click=\"delete\"]")
      |> render_click()

      assert render(view) =~ "Intake already removed"
    end
  end

  describe "log water form" do
    setup %{user: user} do
      alarm_settings_fixture(user, %{goal: 2000, interval_minutes: 60})
      :ok
    end

    test "submitting valid volume logs an intake", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard")

      view
      |> form("#intake-form", intake: %{volume: "250"})
      |> render_submit()

      html = render(view)
      assert html =~ "250"
    end

    test "quick button logs preset volume", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard")

      view
      |> element("button[phx-click=\"quick-log\"][phx-value-volume=\"500\"]")
      |> render_click()

      html = render(view)
      assert html =~ "500"
    end

    test "validates volume on change", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard")

      html =
        view
        |> form("#intake-form", intake: %{volume: "0"})
        |> render_change()

      assert html =~ "must be greater than or equal to 1"
    end

    test "shows error for invalid volume on submit", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard")

      view
      |> form("#intake-form", intake: %{volume: "0"})
      |> render_submit()

      html = render(view)
      assert html =~ "must be greater than or equal to 1"
    end

    test "progress updates after logging water", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard")

      view
      |> form("#intake-form", intake: %{volume: "500"})
      |> render_submit()

      html = render(view)
      assert html =~ "500ml"
      assert html =~ "2000ml"
    end
  end

  describe "weekly summary" do
    setup %{user: user} do
      alarm_settings_fixture(user, %{goal: 2000, interval_minutes: 60})
      :ok
    end

    test "shows 7 day bars", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/dashboard")

      assert html =~ "Weekly Summary"

      today = Date.utc_today()

      for offset <- -6..0 do
        day = Date.add(today, offset)
        day_abbr = Calendar.strftime(day, "%a")
        assert html =~ day_abbr
      end
    end
  end

  describe "next alarm" do
    setup %{user: user} do
      alarm_settings_fixture(user, %{goal: 2000, interval_minutes: 60})
      :ok
    end

    test "shows alarm settings info", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/dashboard")

      assert html =~ "Next Alarm"
      assert html =~ "60"
    end
  end

  describe "alarm settings" do
    setup %{user: user} do
      alarm_settings_fixture(user, %{goal: 2000, interval_minutes: 60})
      :ok
    end

    test "shows current alarm settings", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/dashboard")

      assert html =~ "Alarm Settings"
      assert html =~ "2000"
      assert html =~ "60"
    end

    test "editing alarm settings updates dependent components", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard")

      view
      |> element("button[phx-click=\"edit-settings\"]")
      |> render_click()

      view
      |> form("#alarm-settings-form",
        alarm_settings: %{
          goal: "2500",
          interval_minutes: "45",
          daily_start_time: "08:00",
          daily_end_time: "20:00"
        }
      )
      |> render_submit()

      html = render(view)
      assert html =~ "2500"
      assert html =~ "45"
    end

    test "cancelling edit returns to view mode", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard")

      view
      |> element("button[phx-click=\"edit-settings\"]")
      |> render_click()

      assert render(view) =~ "alarm-settings-form"

      view
      |> element("button[phx-click=\"cancel-edit\"]")
      |> render_click()

      html = render(view)
      refute html =~ "alarm-settings-form"
      assert html =~ "Edit"
    end

    test "validates settings on change", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard")

      view
      |> element("button[phx-click=\"edit-settings\"]")
      |> render_click()

      html =
        view
        |> form("#alarm-settings-form", alarm_settings: %{goal: "0"})
        |> render_change()

      assert html =~ "must be greater than or equal to 50"
    end

    test "shows errors when saving invalid settings", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard")

      view
      |> element("button[phx-click=\"edit-settings\"]")
      |> render_click()

      view
      |> form("#alarm-settings-form",
        alarm_settings: %{
          goal: "0",
          interval_minutes: "5",
          daily_start_time: "05:00",
          daily_end_time: "23:00"
        }
      )
      |> render_submit()

      html = render(view)
      assert html =~ "must be greater than or equal to"
      assert html =~ "must be at or after"
      assert html =~ "must be at or before"
      # Still in edit mode (form visible)
      assert html =~ "alarm-settings-form"
    end
  end
end
