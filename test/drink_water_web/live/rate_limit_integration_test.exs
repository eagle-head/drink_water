defmodule DrinkWaterWeb.RateLimitIntegrationTest do
  @moduledoc """
  Integration tests for rate-limit deny paths in LiveView components.
  Exercises the {:deny, socket} -> {:noreply, socket} branches.
  """
  use DrinkWaterWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import DrinkWater.UserManagementFixtures
  import DrinkWater.HydrationTrackingFixtures

  setup do
    user = user_fixture(%{first_name: "Rate", last_name: "Test"})
    alarm_settings_fixture(user, %{goal: 2000, interval_minutes: 60})

    Application.put_env(:drink_water, :dashboard_user_id, user.id)
    Application.put_env(:drink_water, :rate_limiting_enabled, true)

    on_exit(fn ->
      Application.delete_env(:drink_water, :dashboard_user_id)
      Application.put_env(:drink_water, :rate_limiting_enabled, false)
    end)

    %{user: user}
  end

  defp exhaust_rate_limit(user_id) do
    for _ <- 1..30 do
      DrinkWater.RateLimit.hit("lv:#{user_id}:write", :timer.minutes(1), 30)
    end
  end

  describe "intake form — save deny" do
    test "form save is rejected when rate limited", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      exhaust_rate_limit(user.id)

      view
      |> form("#intake-form", intake: %{volume: "250"})
      |> render_submit()

      # The intake should NOT be created — form stays with no "Water logged!" flash
      html = render(view)
      refute html =~ "Water logged!"
      # No intake was logged, so history still shows empty
      assert html =~ "No water logged today"
    end
  end

  describe "intake form — quick-log deny" do
    test "quick-log is rejected when rate limited", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      exhaust_rate_limit(user.id)

      view
      |> element("button[phx-click=\"quick-log\"][phx-value-volume=\"250\"]")
      |> render_click()

      # The intake should NOT be created
      html = render(view)
      refute html =~ "Water logged!"
      assert html =~ "No water logged today"
    end
  end

  describe "history — delete deny" do
    test "delete is rejected when rate limited", %{conn: conn, user: user} do
      intake =
        water_intake_fixture(user.id, %{date_time_utc: DateTime.utc_now(), volume: 350})

      {:ok, view, _html} = live(conn, ~p"/dashboard")

      exhaust_rate_limit(user.id)

      view
      |> element("[data-intake-id=\"#{intake.id}\"] button[phx-click=\"delete\"]")
      |> render_click()

      # Intake should still be visible since delete was denied
      html = render(view)
      assert html =~ "350"
    end
  end

  describe "alarm settings — save deny" do
    test "alarm settings save is rejected when rate limited", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      # Open edit mode
      view
      |> element("button[phx-click=\"edit-settings\"]")
      |> render_click()

      exhaust_rate_limit(user.id)

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

      # Settings should NOT be updated — still in edit mode, original goal visible
      html = render(view)
      # Still in edit mode (form is still showing)
      assert html =~ "alarm-settings-form"
    end
  end
end
