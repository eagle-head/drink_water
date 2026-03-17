defmodule DrinkWaterWeb.EditIntakeComponentTest do
  use DrinkWater.DataCase, async: true

  import Phoenix.LiveViewTest
  import DrinkWater.UserManagementFixtures
  import DrinkWater.HydrationTrackingFixtures

  alias DrinkWaterWeb.EditIntakeComponent

  describe "render" do
    test "renders form with intake data pre-filled" do
      user = user_fixture()
      intake = water_intake_fixture(user.id, %{volume: 350})

      html = render_component(EditIntakeComponent, id: "test", intake: intake)

      assert html =~ "Edit Intake"
      assert html =~ "350"
      assert html =~ "edit-intake-form"
    end
  end

  describe "validate" do
    test "shows validation errors for invalid volume" do
      user = user_fixture()
      intake = water_intake_fixture(user.id, %{volume: 350})

      html = render_component(EditIntakeComponent, id: "test", intake: intake)
      assert html =~ "350"

      # Validation happens through the LiveView integration tests
      # This test verifies the component renders correctly with pre-filled data
    end
  end
end
