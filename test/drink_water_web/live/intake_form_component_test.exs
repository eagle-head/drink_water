defmodule DrinkWaterWeb.IntakeFormComponentTest do
  use DrinkWaterWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import DrinkWater.UserManagementFixtures

  setup do
    user = user_fixture(%{first_name: "John", last_name: "Doe"})
    alarm_settings_fixture(user, %{goal: 2000, interval_minutes: 60})

    Application.put_env(:drink_water, :dashboard_user_id, user.id)
    on_exit(fn -> Application.delete_env(:drink_water, :dashboard_user_id) end)

    %{user: user}
  end

  describe "quick-log edge cases" do
    test "ignores non-numeric volume", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard")

      # Override phx-value-volume with a non-numeric string
      view
      |> element("button[phx-click=\"quick-log\"][phx-value-volume=\"150\"]")
      |> render_click(%{"volume" => "abc"})

      # Component ignores the invalid value — no crash, no change
      html = render(view)
      assert html =~ "Log Water"
    end

    test "shows flash when quick-log fails validation", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard")

      # Override phx-value-volume with an out-of-range value (> 5000)
      view
      |> element("button[phx-click=\"quick-log\"][phx-value-volume=\"250\"]")
      |> render_click(%{"volume" => "99999"})

      html = render(view)
      assert html =~ "Failed to log water"
    end
  end
end
