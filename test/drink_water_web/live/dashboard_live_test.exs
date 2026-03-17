defmodule DrinkWaterWeb.DashboardLiveTest do
  use DrinkWaterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import DrinkWater.UserManagementFixtures
  import DrinkWater.HydrationTrackingFixtures

  # DashboardLive uses @hardcoded_user_id 1.
  # The first user_fixture() in a clean sandbox gets id=1.
  # Always create the dashboard user FIRST in each test.

  describe "dashboard page" do
    test "renders dashboard with user name", %{conn: conn} do
      _user = user_fixture(%{first_name: "John", last_name: "Doe"})
      {:ok, _view, html} = live(conn, "/dashboard")

      assert html =~ "Hydration Dashboard"
      assert html =~ "John Doe"
    end
  end
end
