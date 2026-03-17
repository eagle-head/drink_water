defmodule DrinkWater.PubSubBroadcastTest do
  use DrinkWater.DataCase, async: true

  import DrinkWater.UserManagementFixtures
  import DrinkWater.HydrationTrackingFixtures

  alias DrinkWater.HydrationTracking

  describe "HydrationTracking broadcasts" do
    test "delete_water_intake/1 broadcasts :intake_deleted" do
      user = user_fixture()
      intake = water_intake_fixture(user.id)
      Phoenix.PubSub.subscribe(DrinkWater.PubSub, "user:#{user.id}")

      {:ok, _} = HydrationTracking.delete_water_intake(intake)

      assert_receive :intake_deleted
    end

    test "delete_water_intake_by_id/2 broadcasts :intake_deleted" do
      user = user_fixture()
      intake = water_intake_fixture(user.id)
      Phoenix.PubSub.subscribe(DrinkWater.PubSub, "user:#{user.id}")

      {:ok, _} = HydrationTracking.delete_water_intake_by_id(user.id, intake.id)

      assert_receive :intake_deleted
    end
  end
end
