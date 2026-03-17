defmodule DrinkWaterWeb.DashboardLiveTest do
  use DrinkWaterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import DrinkWater.UserManagementFixtures
  import DrinkWater.HydrationTrackingFixtures

  # DashboardLive uses @hardcoded_user_id 1.
  # The first user_fixture() in a clean sandbox gets id=1.
  # Always create the dashboard user FIRST in each test.

  # The dashboard uses @hardcoded_user_id 1, which is the seeded John Doe.
  # Seed data: user id=1 (John Doe), alarm_settings (goal=2000),
  # water intakes from 2024-08-14 (not today, so dashboard shows 0ml).

  describe "dashboard page" do
    test "renders dashboard with user name", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/dashboard")

      assert html =~ "Hydration Dashboard"
      assert html =~ "John Doe"
    end
  end

  describe "daily progress" do
    test "shows 0ml when no intakes logged today", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/dashboard")

      assert html =~ "0ml"
      assert html =~ "2000ml"
      assert html =~ "0%"
    end

    test "shows current progress with intakes", %{conn: conn} do
      water_intake_fixture(1, %{date_time_utc: DateTime.utc_now(), volume: 750})

      {:ok, _view, html} = live(conn, "/dashboard")

      assert html =~ "750ml"
      assert html =~ "2000ml"
    end
  end

  describe "today's history" do
    test "shows today's intakes", %{conn: conn} do
      water_intake_fixture(1, %{date_time_utc: DateTime.utc_now(), volume: 250})

      {:ok, _view, html} = live(conn, "/dashboard")

      assert html =~ "250"
    end

    test "shows empty state when no intakes", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/dashboard")

      assert html =~ "No water logged today"
    end

    test "deleting an intake removes it from the list", %{conn: conn} do
      intake = water_intake_fixture(1, %{date_time_utc: DateTime.utc_now(), volume: 350})

      {:ok, view, _html} = live(conn, "/dashboard")

      view
      |> element("[data-intake-id=\"#{intake.id}\"] button[phx-click=\"delete\"]")
      |> render_click()

      refute render(view) =~ "350"
    end
  end
end
