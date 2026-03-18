defmodule DrinkWaterWeb.HistoryComponentTest do
  use DrinkWaterWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import DrinkWater.UserManagementFixtures
  import DrinkWater.HydrationTrackingFixtures

  setup do
    user = user_fixture(%{first_name: "John", last_name: "Doe"})
    alarm_settings_fixture(user, %{goal: 2000, interval_minutes: 60})

    Application.put_env(:drink_water, :dashboard_user_id, user.id)
    on_exit(fn -> Application.delete_env(:drink_water, :dashboard_user_id) end)

    %{user: user}
  end

  alias DrinkWaterWeb.HistoryComponent

  describe "date navigation" do
    test "nav-next navigates forward from yesterday to today", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard")

      # Navigate to yesterday first
      view
      |> element("button[phx-click=\"nav-prev\"]")
      |> render_click()

      yesterday = Date.add(Date.utc_today(), -1)
      html = render(view)
      assert html =~ Calendar.strftime(yesterday, "%b %d, %Y")

      # Now navigate forward back to today
      view
      |> element("button[phx-click=\"nav-next\"]")
      |> render_click()

      html = render(view)
      assert html =~ "Today"
    end

    test "nav-next is disabled when viewing today", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/dashboard")

      assert html =~ "btn-disabled"
    end
  end

  describe "timezone fallback" do
    test "displays times in UTC when timezone is invalid", %{user: user} do
      water_intake_fixture(user.id, %{date_time_utc: ~U[2024-08-14 10:30:00Z], volume: 250})

      html =
        render_component(HistoryComponent,
          id: "test",
          user_id: user.id,
          selected_date: ~D[2024-08-14],
          timezone: "Invalid/Timezone"
        )

      assert html =~ "10:30"
    end
  end

  describe "delete with invalid id" do
    test "ignores non-numeric id values", %{conn: conn, user: user} do
      water_intake_fixture(user.id, %{date_time_utc: DateTime.utc_now(), volume: 300})

      {:ok, view, _html} = live(conn, "/dashboard")

      # Send delete event with non-numeric id directly to the component
      view
      |> element("[data-intake-id] button[phx-click=\"delete\"]")
      |> render_click(%{"id" => "abc"})

      # Component ignores the invalid id — intake remains in the list
      html = render(view)
      assert html =~ "300"
    end
  end
end
