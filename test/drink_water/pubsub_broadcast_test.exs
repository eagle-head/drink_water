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

    test "create_water_intake/2 broadcasts :intake_created" do
      user = user_fixture()
      Phoenix.PubSub.subscribe(DrinkWater.PubSub, "user:#{user.id}")

      {:ok, _} =
        HydrationTracking.create_water_intake(user.id, %{
          date_time_utc: DateTime.utc_now(),
          volume: 250,
          volume_unit: :ml
        })

      assert_receive :intake_created
    end

    test "create_water_intake/2 does not broadcast on failure" do
      user = user_fixture()
      Phoenix.PubSub.subscribe(DrinkWater.PubSub, "user:#{user.id}")

      {:error, _} = HydrationTracking.create_water_intake(user.id, %{})

      refute_receive :intake_created
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
