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
